import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/models.dart';

/// 酷狗搜索（无需登录，返回结果里带 FileHash，正好是 LX 音源需要的 id）
class KugouApi {
  KugouApi(this._dio);

  final Dio _dio;

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  Future<List<Song>> search(String keyword, {int page = 1, int pageSize = 30}) async {
    final Response<String> resp = await _dio.get<String>(
      'https://songsearch.kugou.com/song_search_v2',
      queryParameters: <String, dynamic>{
        'keyword': keyword,
        'page': '$page',
        'pagesize': '$pageSize',
        'platform': 'WebFilter',
        'tag': 'em',
        'filter': '2',
        'iscorrection': '1',
        'privilege_filter': '0',
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Referer': 'https://www.kugou.com/',
          'User-Agent': userAgent,
        },
      ),
    );

    final String body = resp.data ?? '';
    if (body.isEmpty) return <Song>[];

    final Map<String, dynamic> json = jsonDecode(body) as Map<String, dynamic>;
    final Map<String, dynamic>? data = json['data'] as Map<String, dynamic>?;
    final List<dynamic> lists = (data?['lists'] as List<dynamic>?) ?? <dynamic>[];

    return lists
        .whereType<Map<String, dynamic>>()
        .map(_toSong)
        .where((Song s) => s.id.isNotEmpty)
        .toList();
  }

  Song _toSong(Map<String, dynamic> item) {
    final int seconds = (item['Duration'] as num?)?.toInt() ?? 0;
    return Song(
      source: 'kg',
      id: (item['FileHash'] as String? ?? '').toUpperCase(),
      name: _clean(item['SongName']),
      singer: _clean(item['SingerName']),
      album: _clean(item['AlbumName']),
      interval:
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
    );
  }

  static String _clean(Object? raw) {
    return (raw?.toString() ?? '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
