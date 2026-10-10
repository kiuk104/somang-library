import 'package:web/web.dart' as web;

/// 웹 플랫폼 판별 헬퍼 (이 앱은 웹 전용이라 kIsWeb 분기 없이 쓴다).
class WebPlatform {
  WebPlatform._();

  static bool? _iosWebKit;

  /// iPhone / iPad / iPod 의 Safari·크롬·PWA (전부 WebKit 엔진).
  /// iPadOS 는 userAgent 가 'Macintosh' 로 나오므로 터치 지원 여부로 구분한다.
  // ---- 아이폰 강제 종료 원인 분리용 실험 플래그 (도움말 맨 아래 '실험' 에서 켠다) ----
  // localStorage 에 저장되므로 PWA 를 다시 열어도 유지된다. index.html 도 같은 키를 읽는다.
  static const _kNoCovers = 'somang_exp_no_covers';
  static const _kEngine = 'somang_exp_engine'; // '' | 'cpu' | 'multi'

  static const _kImgOff = 'somang_exp_img_off';
  static const _kLowDpr = 'somang_exp_low_dpr';

  /// iOS CPU 렌더링 속도 보완: 기기 픽셀 비율 3x → 2x (그릴 픽셀 55% 감소). 다시 불러와야 적용.
  /// 기본값: iOS 면 켬 (명시적으로 '0' 이면 끔)
  static bool get lowDpr {
    final v = _read(_kLowDpr);
    if (v == null) return isIosWebKit;
    return v == '1';
  }

  static set lowDpr(bool v) => _write(_kLowDpr, v ? '1' : '0');

  /// iOS 에서 표지를 <img> 로 그리는 것(prefer)을 끄고 CanvasKit(fallback)으로 되돌린다
  static bool get imgCoversOff => _read(_kImgOff) == '1';
  static set imgCoversOff(bool v) => _write(_kImgOff, v ? '1' : null);

  static bool get noCovers => _read(_kNoCovers) == '1';
  static set noCovers(bool v) => _write(_kNoCovers, v ? '1' : null);

  /// '' 자동(iOS 는 CPU, 그 외 WebGL) / 'gpu' WebGL 강제 / 'cpu' CPU 렌더링 / 'multi' 다중 서피스+상한 2
  static String get engineMode => _read(_kEngine) ?? '';
  static set engineMode(String v) => _write(_kEngine, v.isEmpty ? null : v);

  static void reload() => web.window.location.reload();

  static String? _read(String k) {
    try {
      return web.window.localStorage.getItem(k);
    } catch (_) {
      return null;
    }
  }

  static void _write(String k, String? v) {
    try {
      if (v == null) {
        web.window.localStorage.removeItem(k);
      } else {
        web.window.localStorage.setItem(k, v);
      }
    } catch (_) {}
  }

  static bool get isIosWebKit {
    return _iosWebKit ??= () {
      final nav = web.window.navigator;
      return RegExp('iPhone|iPad|iPod').hasMatch(nav.userAgent) ||
          (nav.platform == 'MacIntel' && nav.maxTouchPoints > 1);
    }();
  }
}
