import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/local.dart';

/// 阿里云验证码 2.0 服务 — 取代 Cloudflare Turnstile
///
/// 通过隐藏 WebView 内联加载页面（无服务端托管文件），动态引入官方 2.0 SDK
/// （https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js，
/// 国内可达；1.0 的 o.alicdn.com/captcha-web/0.4.6/captcha.js 已 404）。
/// 无痕验证静默通过后把 captchaVerifyParam（JSON 字符串）经 JS channel 回传
/// Dart，再交给后端 VerifyIntelligentCaptcha 校验。
///
/// SDK 关键约束（依据官方文档 + 源码核对，SDK v1.3.4）：
///   - 无痕验证回调参数是 JSON 字符串（sceneId/certifyId/deviceToken/failover），
///     不是含 captchaVerifyParam 字段的对象（那是 1.0 SDK 的形态）；
///   - 回调第二个参数是 ES5 模式的 callback，无痕验证下必须调用
///     callback({captchaResult:true, bizResult:false})，否则 SDK 超时会重发
///     验证码，旧 token 全部作废；
///   - initAliyunCaptcha 只能初始化一次，重试必须整页重载重置 SDK 状态
///     （SDK 未暴露 destroyCaptcha）；
///   - region 仅接受 'cn'/'sgp'，'cn' 之外的取值一律走新加坡端点。
class CaptchaService {
  CaptchaService._();
  static final CaptchaService instance = CaptchaService._();

  Completer<String?>? _completer;
  Completer<void>? _pageReady;
  WebViewController? _controller;
  bool _firstRender = true;

  /// 拼接阿里云验证码页面 HTML（prefix/region/sceneId 由 local.dart 注入）
  static String _buildHtml() => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://o.alicdn.com/captcha-frontend/aliyunCaptcha/AliyunCaptcha.js"></script>
  <style>body { margin: 0; padding: 0; background: transparent; }</style>
</head>
<body>
  <div id="captcha-element"></div>
  <script>
    function __post(status, token, message) {
      CaptchaChannel.postMessage(JSON.stringify({status: status, token: token, message: message}));
    }

    window.__renderCaptcha = function() {
      function doRender() {
        if (typeof initAliyunCaptcha === 'undefined') return;
        try {
          initAliyunCaptcha({
            sceneId: "$kAliyunCaptchaSceneId",
            prefix: "$kAliyunCaptchaPrefix",
            region: "$kAliyunCaptchaRegion",
            mode: 'embed',
            element: '#captcha-element',
            language: 'cn',
            immediate: true,
            captchaVerifyCallback: function(param, callback) {
              // 无痕验证：param 为 JSON 字符串；防对象形态兜底序列化
              var token = (typeof param === 'string') ? param : JSON.stringify(param);
              __post('success', token, null);
              // 必须调用第二参 callback，否则 SDK 超时重发 token 导致旧 token 失效
              if (typeof callback === 'function') {
                callback({captchaResult: true, bizResult: false});
              }
            },
            onBizResultCallback: function(res) {
              // 预留：业务结果回调（无需处理）
            }
          });
        } catch (e) {
          __post('error', null, 'render failed: ' + e.message);
        }
      }

      if (typeof initAliyunCaptcha !== 'undefined') {
        doRender();
      } else {
        var attempts = 0;
        var interval = setInterval(function() {
          attempts++;
          if (typeof initAliyunCaptcha !== 'undefined') {
            clearInterval(interval);
            doRender();
          } else if (attempts >= 90) {
            clearInterval(interval);
            __post('error', null, 'AliyunCaptcha script load timeout (45s)');
          }
        }, 500);
      }
    };
  </script>
</body>
</html>
''';

  /// 配置 WebViewController 并加载阿里云验证码页面
  void bindController(WebViewController controller) {
    _controller = controller;
    _pageReady = Completer<void>();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('CaptchaChannel', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!_pageReady!.isCompleted) _pageReady!.complete();
        },
        onWebResourceError: (err) =>
            debugPrint('[CaptchaService] Resource error: '
                '${err.errorType} — ${err.description}'),
      ))
      ..loadHtmlString(_buildHtml());
  }

  void _onMessage(JavaScriptMessage msg) {
    final c = _completer;
    if (c == null || c.isCompleted) return;
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final status = data['status'];
      if (status == 'success') {
        c.complete(data['token'] as String?);
      } else {
        final message = data['message'];
        if (message != null) {
          debugPrint('[CaptchaService] verify error: $message');
        }
        c.complete(null);
      }
    } catch (_) {
      if (!c.isCompleted) c.complete(null);
    }
  }

  /// 获取阿里云验证码 token（captchaVerifyParam），最多等 45 秒。
  ///
  /// 首次调用直接触发渲染；之后的重试整页重载，规避 SDK「只能初始化一次」。
  Future<String?> getToken() async {
    final controller = _controller;
    if (controller == null) return null;
    _completer = Completer<String?>();

    if (_firstRender) {
      _firstRender = false;
    } else {
      _pageReady = Completer<void>();
      await controller.loadHtmlString(_buildHtml());
    }
    await _pageReady!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );

    await controller.runJavaScript('window.__renderCaptcha()');

    return _completer!.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => null,
    );
  }
}
