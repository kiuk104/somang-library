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
  static const _kDpr = 'somang_exp_dpr';

  /// 기기 픽셀 비율이 3 이상(iPhone 12 이후 대부분, 미니 포함)인 WebKit 기기.
  /// GPU 메모리는 배율의 제곱에 비례해 이 기기들에서만 강제 종료가 난다 (SE 같은 2x 는 괜찮음).
  static bool get isIosHighDpr => isIosWebKit && _rawDpr >= 3;

  static double get _rawDpr => web.window.devicePixelRatio.toDouble();

  /// 화면 해상도 배율: '3' 기기 그대로 / '2' / '1' 최저사양. 다시 불러와야 적용.
  /// 기본값: 3x iOS 기기는 '2' (CPU 렌더링 속도 보완), 그 외는 기기 그대로.
  static String get dprMode {
    final v = _read(_kDpr);
    if (v == '1' || v == '2' || v == '3') return v!;
    return isIosHighDpr ? '2' : '3';
  }

  static set dprMode(String v) => _write(_kDpr, v);

  /// 적용할 devicePixelRatio (null 이면 기기 그대로)
  static double? get dprOverride {
    final m = dprMode;
    if (m == '3') return null;
    final target = double.parse(m);
    return _rawDpr > target ? target : null; // 원래보다 높게는 안 올린다
  }

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
