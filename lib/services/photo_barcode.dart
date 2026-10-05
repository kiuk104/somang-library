import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// web/index.html 의 somangReadBarcodes — zxing-wasm(web/zxing 에 자체 호스팅)으로
/// 이미지에서 EAN-13/EAN-8/UPC-A 바코드를 읽어 문자열 배열을 돌려준다.
@JS('somangReadBarcodes')
external JSPromise<JSArray<JSString>> _readBarcodes(web.Blob image);

/// 찍은 사진에서 바코드 읽기
///
/// 브라우저 실시간 카메라·내장 BarcodeDetector 는 기기(특히 갤럭시)에 따라 전혀 인식이 안 돼서
/// 폰 기본 카메라 사진 + zxing-wasm 으로 읽는다. (흐림·기울어짐에 강함, 아이폰 Safari 도 동작)
class PhotoBarcode {
  static Future<List<String>> read(Uint8List bytes, String mimeType) async {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final values = await _readBarcodes(blob).toDart;
    return values.toDart.map((s) => s.toDart).toList();
  }
}
