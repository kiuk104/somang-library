import 'package:web/web.dart' as web;

/// 웹 플랫폼 판별 헬퍼 (이 앱은 웹 전용이라 kIsWeb 분기 없이 쓴다).
class WebPlatform {
  WebPlatform._();

  static bool? _iosWebKit;

  /// iPhone / iPad / iPod 의 Safari·크롬·PWA (전부 WebKit 엔진).
  /// iPadOS 는 userAgent 가 'Macintosh' 로 나오므로 터치 지원 여부로 구분한다.
  static bool get isIosWebKit {
    return _iosWebKit ??= () {
      final nav = web.window.navigator;
      return RegExp('iPhone|iPad|iPod').hasMatch(nav.userAgent) ||
          (nav.platform == 'MacIntel' && nav.maxTouchPoints > 1);
    }();
  }
}
