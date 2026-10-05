import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// 브라우저 내장 BarcodeDetector (Chrome·Android, Safari 17+)
@JS('BarcodeDetector')
extension type _BarcodeDetector._(JSObject _) implements JSObject {
  external _BarcodeDetector();
  external JSPromise<JSArray<_DetectedBarcode>> detect(JSObject image);
}

extension type _DetectedBarcode._(JSObject _) implements JSObject {
  external String get rawValue;
}

/// 찍은 사진에서 바코드 읽기
///
/// 실시간 카메라(웹)는 해상도가 낮고 초점이 잘 안 맞아 책 바코드를 놓치는 경우가 많다.
/// 폰 기본 카메라로 찍은 사진은 자동초점·고해상도라 훨씬 잘 읽힌다.
class PhotoBarcode {
  /// 이 브라우저가 BarcodeDetector 를 지원하는지
  static bool get supported => globalContext.has('BarcodeDetector');

  /// 이미지 주소(blob: URL 등)에서 읽힌 바코드 값들
  static Future<List<String>> detect(String imageUrl) async {
    final img = web.HTMLImageElement()..src = imageUrl;
    await img.decode().toDart;
    final found = await _BarcodeDetector().detect(img).toDart;
    return found.toDart.map((b) => b.rawValue).toList();
  }
}
