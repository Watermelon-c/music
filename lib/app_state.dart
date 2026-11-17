import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/lyric.dart';
import 'models/models.dart';
import 'services/kugou_api.dart';
import 'services/lx_host.dart';
import 'services/lyric_api.dart';
import 'services/player_service.dart';

class PresetSource {
  const PresetSource(this.name, this.url);
  final String name;
  final String url;
}

/// 播放顺序
enum PlayMode { sequence, shuffle, repeatOne }

/// 内置推荐音源（来自 pdone/lx-music-source，走 GitHub 加速链接）
const List<PresetSource> kPresetSources = <PresetSource>[
  PresetSource(
    'HelloWorld',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/helloworld/latest.js',
  ),
  PresetSource(
    'ChangQing',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/changqing/latest.js',
  ),
  PresetSource(
    'Fish',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/fish/latest.js',
  ),
  PresetSource(
    'XingHai',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/xinghai/latest.js',
  ),
  PresetSource(
    'SixYin',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
  ),
  PresetSource(
    'QingLiang',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/qingliang/latest.js',
  ),
  PresetSource(
    'SuYin',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/suyin/latest.js',
  ),
  PresetSource(
    'XingLan',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/xinglan/latest.js',
  ),
  PresetSource(
    'FeiChangDao',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/feichangdao/latest.js',
  ),
  PresetSource(
    'QDY',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/qdy/latest.js',
  ),
  PresetSource(
    'JieXiang',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/jiexiang/latest.js',
  ),
  PresetSource(
    'HuanYin',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/huanyin/latest.js',
  ),
  PresetSource(
    'HYW',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/hyw/latest.js',
  ),
  PresetSource(
    'LX',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js',
  ),
];

class AppState extends ChangeNotifier {
  AppState() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
        headers: <String, String>{'User-Agent': KugouApi.userAgent},
      ),
    );
    kugou = KugouApi(dio);
    host = LxHost(dio);
    lyricApi = LyricApi(dio);
    player = PlayerService();
    player.addListener(notifyListeners);
    player.player.playerStateStream.listen(_onPlayerState);
  }

  late final Dio dio;
  late final KugouApi kugou;
  late final LxHost host;
  late final LyricApi lyricApi;
  late final PlayerService player;

  SharedPreferences? _prefs;
  int _sourceSeq = 0;

  List<Song> results = <Song>[];
  List<Song> favorites = <Song>[];
  List<SourceEntry> sources = <SourceEntry>[];
  List<RankInfo> ranks = <RankInfo>[];
  List<Song> daily = <Song>[];

  bool homeLoading = false;
  String? homeError;
  String _dailyDate = '';

  PlayMode playMode = PlayMode.sequence;

  String keyword = '';
  String quality = '320k';
  bool searching = false;
  bool busy = false;
  String? searchError;
  String? notice;

  // ------------------------------------------------------------------ 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    quality = _prefs?.getString('quality') ?? '320k';
    final int modeIndex = (_prefs?.getInt('playMode') ?? 0).clamp(0, 2);
    playMode = PlayMode.values[modeIndex];

    final String? favRaw = _prefs?.getString('favorites');
    if (favRaw != null && favRaw.isNotEmpty) {
      try {
        favorites = (jsonDecode(favRaw) as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(Song.fromJson)
            .toList();
      } catch (_) {
        favorites = <Song>[];
      }
    }

    final List<String> rawSources = _prefs?.getStringList('sources') ?? <String>[];
    final List<SourceEntry> loaded = <SourceEntry>[];
    for (final String raw in rawSources) {
      try {
        loaded.add(SourceEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // 忽略坏的记录
      }
    }
    sources = loaded;

    unawaited(restoreSources());
  }

  /// 启动时把已导入的音源重新加载进 WebView 宿主
  Future<void> restoreSources() async {
    for (final SourceEntry s in List<SourceEntry>.from(sources)) {
      if (!s.enabled) continue;
      try {
        await _activate(s, save: false);
      } catch (e) {
        s.enabled = false;
      }
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------- 搜索
  Future<void> search(String kw) async {
    final String text = kw.trim();
    if (text.isEmpty) return;

    keyword = text;
    searching = true;
    searchError = null;
    notice = null;
    notifyListeners();

    try {
      results = await kugou.search(text);
      if (results.isEmpty) searchError = '没有搜到「$text」';
    } catch (e) {
      results = <Song>[];
      searchError = '搜索失败：$e';
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------- 播放
  List<Song> queue = <Song>[];
  int queueIndex = -1;
  Lyric lyric = Lyric.empty;
  bool lyricLoading = false;

  final Map<String, _CachedUrl> _urlCache = <String, _CachedUrl>{};
  int _playToken = 0;

  void _syncQueue(Song song) {
    final int i = results.indexWhere((Song s) => s.key == song.key);
    if (i >= 0) {
      queue = List<Song>.from(results);
      queueIndex = i;
      return;
    }
    final int j = favorites.indexWhere((Song s) => s.key == song.key);
    if (j >= 0) {
      queue = List<Song>.from(favorites);
      queueIndex = j;
      return;
    }
    queue = <Song>[song];
    queueIndex = 0;
  }

  Future<void> nextSong() async {
    if (queue.isEmpty) return;
    final Song? next = _pickNext(auto: false);
    if (next == null) return;
    await play(next, queue: queue, index: queueIndex);
  }

  Future<void> previousSong() async {
    if (queue.isEmpty) return;
    final int prev = (queueIndex - 1 + queue.length) % queue.length;
    await play(queue[prev], queue: queue, index: prev);
  }

  /// 播放顺序：顺序 → 随机 → 单曲循环
  Future<void> cyclePlayMode() async {
    playMode = PlayMode.values[(playMode.index + 1) % PlayMode.values.length];
    await _prefs?.setInt('playMode', playMode.index);
    notifyListeners();
  }

  bool _advancing = false;

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      unawaited(_handleCompleted());
    }
  }

  Future<void> _handleCompleted() async {
    if (_advancing) return;
    _advancing = true;
    try {
      if (playMode == PlayMode.repeatOne) {
        await player.player.seek(Duration.zero);
        await player.player.play();
        return;
      }
      final Song? next = _pickNext(auto: true);
      if (next != null) {
        await play(next, queue: queue, index: queueIndex);
      } else {
        notice = '播放列表已经播完啦，去首页挑点别的吧';
        notifyListeners();
      }
    } finally {
      _advancing = false;
    }
  }

  /// auto=true 时顺序播放到列表末尾会返回 null（停止），auto=false 时循环回第一首
  Song? _pickNext({required bool auto}) {
    if (queue.isEmpty) return null;

    if (playMode == PlayMode.shuffle) {
      if (queue.length == 1) {
        queueIndex = 0;
        return queue.first;
      }
      final Random rnd = Random();
      int i = queueIndex;
      while (i == queueIndex) {
        i = rnd.nextInt(queue.length);
      }
      queueIndex = i;
      return queue[i];
    }

    final int next = queueIndex + 1;
    if (next < queue.length) {
      queueIndex = next;
      return queue[next];
    }
    if (!auto) {
      queueIndex = 0;
      return queue.first;
    }
    return null;
  }

  // -------------------------------------------------------------------- 首页
  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> loadHome({bool force = false}) async {
    final String today = _todayKey();
    if (!force && daily.isNotEmpty && _dailyDate == today) return;

    homeLoading = true;
    homeError = null;
    notifyListeners();

    try {
      if (ranks.isEmpty) ranks = await kugou.ranks();

      final List<Song> pool = <Song>[];
      for (final RankInfo r in ranks.take(3)) {
        try {
          final List<Song> songs = await kugou.rankSongs(r.id);
          pool.addAll(songs.take(12));
        } catch (_) {
          // 单个榜单失败不影响整体
        }
      }

      final List<Song> shuffled = List<Song>.from(pool);
      shuffled.shuffle(Random(today.hashCode));
      daily = shuffled.take(30).toList();
      _dailyDate = today;

      if (daily.isEmpty) homeError = '推荐数据拉取失败，下拉重试';
    } catch (e) {
      homeError = '首页加载失败：$e';
    } finally {
      homeLoading = false;
      notifyListeners();
    }
  }

  Future<void> playDaily() async {
    if (daily.isEmpty) {
      await loadHome(force: true);
    }
    if (daily.isEmpty) return;
    await play(daily.first, queue: daily, index: 0);
  }

  Future<void> play(Song song, {List<Song>? queue, int? index}) async {
    if (queue != null) {
      this.queue = List<Song>.from(queue);
      queueIndex = index ?? 0;
    } else {
      _syncQueue(song);
    }

    final List<SourceEntry> active = sources
        .where((SourceEntry s) =>
            s.enabled &&
            (s.platforms.isEmpty || s.platforms.contains(song.source)))
        .toList();

    if (active.isEmpty) {
      notice = '还没有可用音源，请先到「音源」页导入一个';
      notifyListeners();
      return;
    }

    final int token = ++_playToken;
    busy = true;
    notice = null;
    lyric = Lyric.empty;
    lyricLoading = true;
    notifyListeners();

    // 1) 直链缓存（10 分钟内有效），重播同一首基本秒开
    final String cacheKey = '${song.key}|$quality';
    final _CachedUrl? cached = _urlCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.at).inMinutes < 10) {
      await player.playUrl(
        song,
        cached.url,
        headers: <String, String>{'User-Agent': KugouApi.userAgent},
      );
      busy = false;
      lyricLoading = false;
      notifyListeners();
      unawaited(_loadLyric(song, token));
      return;
    }

    // 2) 所有音源 + 两档音质并发抢答，谁先返回有效地址就用谁
    final List<String> qualities = <String>[
      quality,
      if (quality != '128k') '128k',
    ];
    final List<Future<String>> attempts = <Future<String>>[];
    final List<String> labels = <String>[];
    for (final String q in qualities) {
      for (final SourceEntry s in active) {
        labels.add('${s.name}($q)');
        attempts.add(
          host.resolve(
            sourceId: s.id,
            platform: song.source,
            quality: q,
            musicInfo: song.toMusicInfo(),
          ),
        );
      }
    }

    try {
      final String url = await _firstSuccess(attempts)
          .timeout(const Duration(seconds: 18));
      if (token != _playToken) return;

      _urlCache[cacheKey] = _CachedUrl(url, DateTime.now());
      if (_urlCache.length > 60) _urlCache.clear();

      await player.playUrl(
        song,
        url,
        headers: <String, String>{'User-Agent': KugouApi.userAgent},
      );
      busy = false;
      lyricLoading = false;
      notifyListeners();
      unawaited(_loadLyric(song, token));
    } catch (e) {
      if (token != _playToken) return;
      busy = false;
      lyricLoading = false;
      notice = '所有音源都没解析出地址（多半是音源后端挂了）。\n'
          '去「音源」页点「一键导入全部推荐音源」，再回来重试。';
      notifyListeners();
    }
  }

  Future<void> _loadLyric(Song song, int token) async {
    try {
      final Lyric result = await lyricApi.fetch(song);
      if (token != _playToken) return;
      lyric = result;
    } catch (_) {
      if (token != _playToken) return;
      lyric = Lyric.empty;
    } finally {
      if (token == _playToken) {
        lyricLoading = false;
        notifyListeners();
      }
    }
  }

  /// 返回第一个成功的 Future，全部失败才抛错
  Future<String> _firstSuccess(List<Future<String>> futures) {
    final Completer<String> completer = Completer<String>();
    int remaining = futures.length;
    for (final Future<String> f in futures) {
      f.then(
        (String value) {
          if (!completer.isCompleted) completer.complete(value);
        },
        onError: (Object error) {
          remaining -= 1;
          if (remaining == 0 && !completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
    }
    return completer.future;
  }

  /// 一键导入所有还没导入的推荐音源，返回结果描述
  Future<String> importAllPresets() async {
    final Set<String> existed =
        sources.map((SourceEntry s) => s.url).toSet();
    final List<PresetSource> todo = kPresetSources
        .where((PresetSource p) => !existed.contains(p.url))
        .toList();
    if (todo.isEmpty) return '推荐音源都已经导入过了';

    busy = true;
    notice = null;
    notifyListeners();

    int ok = 0;
    await Future.wait(todo.map((PresetSource p) async {
      final String? error = await importSource(p.url);
      if (error == null) ok += 1;
    }));

    busy = false;
    notifyListeners();
    return '导入完成：成功 $ok / ${todo.length} 个';
  }

  // -------------------------------------------------------------------- 音源
  Future<String?> importSource(String url) async {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return '链接不能为空';

    try {
      final String code = await _download(trimmed);
      _sourceSeq += 1;
      final String id = 'src_${DateTime.now().microsecondsSinceEpoch}_$_sourceSeq';
      final Map<String, dynamic> caps =
          await host.addSource(id, code, name: _nameFromCode(code, trimmed));

      final SourceEntry entry = SourceEntry(
        id: id,
        name: _nameFromCode(code, '音源'),
        url: trimmed,
        code: code,
        platforms: caps.keys.toList(),
      );
      sources = <SourceEntry>[...sources, entry];
      await _persistSources();
      notifyListeners();
      return null;
    } catch (e) {
      return '导入失败：$e';
    }
  }

  Future<void> removeSource(SourceEntry entry) async {
    sources = sources.where((SourceEntry s) => s.id != entry.id).toList();
    await host.removeSource(entry.id);
    await _persistSources();
    notifyListeners();
  }

  Future<void> toggleSource(SourceEntry entry, bool enabled) async {
    entry.enabled = enabled;
    if (enabled) {
      try {
        await _activate(entry, save: false);
      } catch (e) {
        entry.enabled = false;
        notice = '${entry.name} 加载失败：$e';
      }
    }
    await _persistSources();
    notifyListeners();
  }

  Future<void> _activate(SourceEntry entry, {bool save = true}) async {
    final String code = entry.code ?? await _download(entry.url);
    final Map<String, dynamic> caps =
        await host.addSource(entry.id, code, name: entry.name);
    entry.code = code;
    entry.platforms = caps.keys.toList();
    if (save) {
      await _persistSources();
      notifyListeners();
    }
  }

  Future<String> _download(String url) async {
    final Response<String> resp = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (int? code) => code != null && code < 400,
      ),
    );
    final String text = resp.data ?? '';
    if (text.trim().isEmpty) throw Exception('下载到的内容是空的');
    if (!text.contains('lx')) throw Exception('这看起来不是 LX 音源脚本');
    return text;
  }

  String _nameFromCode(String code, String fallback) {
    final RegExpMatch? m = RegExp(r'@name\s+(.+)').firstMatch(code);
    final String? name = m?.group(1)?.trim();
    if (name == null || name.isEmpty) return '自定义音源';
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  Future<void> _persistSources() async {
    final List<String> raw = sources
        .map((SourceEntry s) => jsonEncode(s.toJson()))
        .toList();
    await _prefs?.setStringList('sources', raw);
  }

  // -------------------------------------------------------------------- 收藏
  bool isFavorite(Song song) =>
      favorites.any((Song s) => s.key == song.key);

  Future<void> toggleFavorite(Song song) async {
    if (isFavorite(song)) {
      favorites = favorites.where((Song s) => s.key != song.key).toList();
    } else {
      favorites = <Song>[song, ...favorites];
    }
    await _prefs?.setString(
      'favorites',
      jsonEncode(favorites.map((Song s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  // -------------------------------------------------------------------- 设置
  Future<void> setQuality(String q) async {
    quality = q;
    await _prefs?.setString('quality', q);
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

class _CachedUrl {
  const _CachedUrl(this.url, this.at);

  final String url;
  final DateTime at;
}
