import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/models.dart';
import 'services/kugou_api.dart';
import 'services/lx_host.dart';
import 'services/player_service.dart';

class PresetSource {
  const PresetSource(this.name, this.url);
  final String name;
  final String url;
}

/// 内置推荐音源（来自 pdone/lx-music-source，走 GitHub 加速链接）
const List<PresetSource> kPresetSources = <PresetSource>[
  PresetSource(
    'HelloWorld 聚合',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/helloworld/latest.js',
  ),
  PresetSource(
    'LX',
    'https://gh-proxy.org/raw.githubusercontent.com/pdone/lx-music-source/main/lx/latest.js',
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
    player = PlayerService();
    player.addListener(notifyListeners);
  }

  late final Dio dio;
  late final KugouApi kugou;
  late final LxHost host;
  late final PlayerService player;

  SharedPreferences? _prefs;

  List<Song> results = <Song>[];
  List<Song> favorites = <Song>[];
  List<SourceEntry> sources = <SourceEntry>[];

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
  Future<void> play(Song song) async {
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

    busy = true;
    notice = null;
    notifyListeners();

    final List<String> tried = <String>[];
    final List<String> qualities = <String>[
      quality,
      if (quality != '128k') '128k',
    ];

    for (final String q in qualities) {
      for (final SourceEntry s in active) {
        try {
          final String url = await host.resolve(
            sourceId: s.id,
            platform: song.source,
            quality: q,
            musicInfo: song.toMusicInfo(),
          );
          await player.playUrl(
            song,
            url,
            headers: <String, String>{'User-Agent': KugouApi.userAgent},
          );
          busy = false;
          notifyListeners();
          return;
        } catch (e) {
          tried.add('${s.name}($q): $e');
        }
      }
    }

    busy = false;
    notice = '所有音源都没解析出地址，换首歌或换个音源试试\n${tried.take(2).join('\n')}';
    notifyListeners();
  }

  // -------------------------------------------------------------------- 音源
  Future<String?> importSource(String url) async {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return '链接不能为空';

    try {
      final String code = await _download(trimmed);
      final String id = 'src_${DateTime.now().millisecondsSinceEpoch}';
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
