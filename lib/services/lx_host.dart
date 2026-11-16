import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// 跑在隐藏 WebView 里的 LX 自定义源宿主。
///
/// 音频解析全部发生在 JS 里，网络请求由 Dart 侧代发（等同 LX 的 lx.request），
/// 这样就不受浏览器 CORS 限制。
class LxHost {
  LxHost(this._dio);

  final Dio _dio;
  final Completer<void> _ready = Completer<void>();
  final Map<String, Completer<Map<String, dynamic>>> _loadWaiters =
      <String, Completer<Map<String, dynamic>>>{};
  final Map<int, Completer<String>> _resolveWaiters = <int, Completer<String>>{};

  WebViewController? _controller;
  bool _md5Loaded = false;
  int _seq = 0;

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  WebViewController ensureController() {
    final WebViewController? existing = _controller;
    if (existing != null) return existing;

    final WebViewController c = WebViewController();
    c.setJavaScriptMode(JavaScriptMode.unrestricted);
    c.setBackgroundColor(const Color(0x00000000));
    c.addJavaScriptChannel('LxBridge', onMessageReceived: _onMessage);
    c.loadFlutterAsset('assets/lx/host.html');
    _controller = c;
    return c;
  }

  /// 加载一个音源脚本，返回它声明的 sources（平台 -> 能力）
  Future<Map<String, dynamic>> addSource(
    String id,
    String code, {
    String name = '',
  }) async {
    final WebViewController c = ensureController();
    await _ready.future.timeout(const Duration(seconds: 20));

    final Completer<Map<String, dynamic>> waiter =
        Completer<Map<String, dynamic>>();
    _loadWaiters[id] = waiter;

    final String info = jsonEncode(<String, String>{'name': name});
    final String js =
        'window.__lxAddSource(${jsonEncode(code)}, ${jsonEncode(id)}, ${jsonEncode(info)});';
    await c.runJavaScript(js);

    return waiter.future.timeout(const Duration(seconds: 30));
  }

  Future<void> removeSource(String id) async {
    final WebViewController? c = _controller;
    if (c == null) return;
    _loadWaiters.remove(id);
    await c.runJavaScript('window.__lxRemoveSource(${jsonEncode(id)});');
  }

  /// 让指定音源解析播放地址
  Future<String> resolve({
    required String sourceId,
    required String platform,
    required String quality,
    required Map<String, dynamic> musicInfo,
  }) async {
    final WebViewController c = ensureController();
    await _ready.future.timeout(const Duration(seconds: 20));

    final int rid = ++_seq;
    final Completer<String> waiter = Completer<String>();
    _resolveWaiters[rid] = waiter;

    final String js = 'window.__lxRequest($rid, ${jsonEncode(sourceId)}, '
        '${jsonEncode(platform)}, ${jsonEncode(quality)}, ${jsonEncode(musicInfo)});';
    await c.runJavaScript(js);

    try {
      return await waiter.future.timeout(const Duration(seconds: 20));
    } finally {
      _resolveWaiters.remove(rid);
    }
  }

  // ---------------------------------------------------------------- 消息处理
  void _onMessage(dynamic message) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(message.message as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'ready':
        _injectMd5();
        break;
      case 'http':
        _handleHttp(msg);
        break;
      case 'inited':
        final String id = msg['id'] as String? ?? '';
        final Map<String, dynamic> sources =
            (msg['sources'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
                .cast<String, dynamic>();
        _loadWaiters.remove(id)?.complete(sources);
        break;
      case 'error':
        final String id = msg['id'] as String? ?? '';
        final String text = msg['message'] as String? ?? '脚本执行失败';
        _loadWaiters.remove(id)?.completeError(Exception(text));
        break;
      case 'result':
        final int rid = (msg['rid'] as num).toInt();
        _resolveWaiters.remove(rid)?.complete(msg['url'] as String? ?? '');
        break;
      case 'fail':
        final int rid = (msg['rid'] as num).toInt();
        final String text = msg['message'] as String? ?? '解析失败';
        _resolveWaiters.remove(rid)?.completeError(Exception(text));
        break;
    }
  }

  Future<void> _injectMd5() async {
    if (_md5Loaded) {
      if (!_ready.isCompleted) _ready.complete();
      return;
    }
    _md5Loaded = true;
    try {
      final String js = await rootBundle.loadString('assets/lx/md5.js');
      await _controller?.runJavaScript(js);
    } catch (_) {
      // md5 缺失不影响不使用 crypto 的音源
    }
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> _handleHttp(Map<String, dynamic> msg) async {
    final WebViewController? c = _controller;
    if (c == null) return;

    final String rid = msg['rid'] as String? ?? '';
    final String url = msg['url'] as String? ?? '';
    final Map<String, dynamic> opts =
        (msg['options'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    Map<String, dynamic> payload;
    try {
      final Map<String, String> headers = <String, String>{
        'User-Agent': userAgent,
      };
      final Object? rawHeaders = opts['headers'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((dynamic k, dynamic v) {
          if (k != null && v != null) headers['$k'] = '$v';
        });
      }

      Object? data = opts['body'];
      if (data is Map || data is List) {
        data = jsonEncode(data);
        headers.putIfAbsent('Content-Type', () => 'application/json');
      }

      final int timeoutMs =
          int.tryParse('${opts['timeout'] ?? ''}') ?? 15000;

      final Response<String> resp = await _dio.request<String>(
        url,
        data: data,
        options: Options(
          method: (opts['method'] as String? ?? 'GET').toUpperCase(),
          headers: headers,
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (_) => true,
          sendTimeout: Duration(milliseconds: timeoutMs),
          receiveTimeout: Duration(milliseconds: timeoutMs + 5000),
        ),
      );

      payload = <String, dynamic>{
        'statusCode': resp.statusCode ?? 200,
        'body': resp.data ?? '',
        'url': resp.realUri.toString(),
        'headers': resp.headers.map
            .map((String k, List<String> v) => MapEntry<String, String>(k, v.join(', '))),
      };
    } catch (e) {
      payload = <String, dynamic>{'__error': '$e'};
    }

    await c.runJavaScript(
      'window.__lxHttpDone(${jsonEncode(rid)}, ${jsonEncode(jsonEncode(payload))});',
    );
  }
}
