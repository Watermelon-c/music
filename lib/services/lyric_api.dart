import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/lyric.dart';
import '../models/models.dart';

/// 酷狗歌词：先用 hash 搜候选，再按 id + accesskey 下载 LRC（base64）
class LyricApi {
  LyricApi(this._dio);

  final Dio _dio;

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  Future<Lyric> fetch(Song song) async {
    if (song.source != 'kg' || song.id.isEmpty) return Lyric.empty;

    final Response<String> search = await _dio.get<String>(
      'https://krcs.kugou.com/search',
      queryParameters: <String, dynamic>{
        'ver': '1',
        'man': 'yes',
        'client': 'mobi',
        'keyword': '',
        'duration': '',
        'hash': song.id,
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'User-Agent': _ua,
          'Referer': 'https://www.kugou.com/',
        },
      ),
    );

    final Map<String, dynamic> json =
        jsonDecode(search.data ?? '{}') as Map<String, dynamic>;
    final List<dynamic> candidates =
        (json['candidates'] as List<dynamic>?) ?? <dynamic>[];
    if (candidates.isEmpty) return Lyric.empty;

    final Map<String, dynamic> first =
        candidates.first as Map<String, dynamic>;
    final String id = '${first['id'] ?? ''}';
    final String accessKey = '${first['accesskey'] ?? ''}';
    if (id.isEmpty || accessKey.isEmpty) return Lyric.empty;

    final Response<String> download = await _dio.get<String>(
      'https://lyrics.kugou.com/download',
      queryParameters: <String, dynamic>{
        'ver': '1',
        'client': 'pc',
        'id': id,
        'accesskey': accessKey,
        'fmt': 'lrc',
        'charset': 'utf8',
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{'User-Agent': _ua},
      ),
    );

    final Map<String, dynamic> body =
        jsonDecode(download.data ?? '{}') as Map<String, dynamic>;
    final String content = '${body['content'] ?? ''}';
    if (content.isEmpty) return Lyric.empty;

    return Lyric.parse(utf8.decode(base64Decode(content)));
  }
}
