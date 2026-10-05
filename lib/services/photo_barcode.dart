import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// web/scanner.js — zxing-wasm(web/zxing 에 자체 호스팅)으로 책 바코드를 읽는다.
@JS('somangScanLive')
external JSPromise<JSString?> _scanLive();

@JS('somangReadBarcodes')
external JSPromise<JSArray<JSString>> _readBarcodes(web.Blob image);

/// 책 바코드(ISBN) 읽기
///
/// 브라우저 내장 BarcodeDetector 는 갤럭시에서 인식이 안 돼서 쓰지 않는다.
/// - 실시간: 후면 메인 카메라(연속 자동초점) 영상을 zxing-wasm 으로 계속 읽는다
/// - 사진: 폰 기본 카메라로 찍은 사진 한 장을 읽는다
class PhotoBarcode {
  /// 실시간 스캔 화면(전체화면)을 띄우고, 찾은 ISBN 을 돌려준다. 닫으면 null
  static Future<String?> scanLive() async {
    final result = await _scanLive().toDart;
    return result?.toDart;
  }

  /// 사진에서 읽힌 바코드 값들
  static Future<List<String>> read(Uint8List bytes, String mimeType) async {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final values = await _readBarcodes(blob).toDart;
    return values.toDart.map((s) => s.toDart).toList();
  }
}
