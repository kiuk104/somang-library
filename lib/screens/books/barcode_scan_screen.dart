import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/book_lookup_service.dart';

/// 책 뒷면 ISBN 바코드 찍기 — 찾으면 ISBN 문자열을 돌려주며 닫힌다
/// (웹은 https 또는 localhost 에서만 카메라 사용 가능)
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final isbn = BookLookupService.cleanIsbn(barcode.rawValue ?? '');
      // 책 ISBN 은 978/979 로 시작 (가격 바코드 등은 무시)
      if (isbn != null && isbn.length == 13 &&
          (isbn.startsWith('978') || isbn.startsWith('979'))) {
        _done = true;
        Navigator.of(context).pop(isbn);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('바코드 찍기'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '카메라를 열 수 없어요.\n브라우저의 카메라 권한을 확인해 주세요.\n\n(${error.errorCode.name})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          // 가이드 박스
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              '책 뒷면의 ISBN 바코드(978…)를 네모 안에 맞춰 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
