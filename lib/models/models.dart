/// 数据模型
class Song {
  const Song({
    required this.source,
    required this.id,
    required this.name,
    required this.singer,
    required this.album,
    required this.interval,
    this.cover = '',
  });

  /// 平台标识：kg（酷狗）/ kw / tx / wy / mg
  final String source;

  /// 平台内的歌曲 ID：酷狗是 FileHash
  final String id;
  final String name;
  final String singer;
  final String album;

  /// mm:ss
  final String interval;

  /// 专辑封面（可能为空）
  final String cover;

  String get key => '$source:$id';

  /// 传给 LX 音源脚本的 musicInfo，字段名要和 LX 保持一致
  Map<String, dynamic> toMusicInfo() => <String, dynamic>{
        'source': source,
        'hash': id,
        'songmid': id,
        'name': name,
        'singer': singer,
        'albumName': album,
        'interval': interval,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'id': id,
        'name': name,
        'singer': singer,
        'album': album,
        'interval': interval,
        'cover': cover,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        source: json['source'] as String? ?? 'kg',
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        singer: json['singer'] as String? ?? '',
        album: json['album'] as String? ?? '',
        interval: json['interval'] as String? ?? '00:00',
        cover: json['cover'] as String? ?? '',
      );
}

/// 榜单 / 推荐歌单
class RankInfo {
  const RankInfo({
    required this.id,
    required this.name,
    required this.cover,
    required this.intro,
  });

  final int id;
  final String name;
  final String cover;
  final String intro;

  factory RankInfo.fromJson(Map<String, dynamic> json) => RankInfo(
        id: (json['rankid'] as num?)?.toInt() ?? 0,
        name: '${json['rankname'] ?? ''}',
        cover: '${json['banner_9'] ?? json['img_9'] ?? json['imgurl'] ?? ''}'
            .replaceAll('{size}', '400'),
        intro: '${json['intro'] ?? ''}',
      );
}

/// 已导入的音源
class SourceEntry {
  SourceEntry({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.code,
    this.platforms = const <String>[],
  });

  final String id;
  final String name;
  final String url;
  bool enabled;

  /// 音源脚本正文，首次导入后缓存，下次启动优先用缓存
  String? code;

  /// 该音源声明支持的平台，例如 ['kw','kg','tx','wy','mg']
  List<String> platforms;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'url': url,
        'enabled': enabled,
      };

  factory SourceEntry.fromJson(Map<String, dynamic> json) => SourceEntry(
        id: json['id'] as String,
        name: json['name'] as String? ?? '音源',
        url: json['url'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
}
