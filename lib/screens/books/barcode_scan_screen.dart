import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/book_lookup_service.dart';

/// 책 뒷면 ISBN 바코드 찍기 — 찾으면 ISBN 문자열을 돌려주며 닫힌다
/// (웹은 https 또는 localhost 에서만 카메라 사용 가능)
///
/// 한국 책은 ISBN 바코드 옆에 5자리 부가기호 바코드가 붙어 있어서
/// 스캐너가 18자리로 읽거나 부가기호만 읽기도 한다 → 978/979 로 시작하는 13자리만 골라낸다.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  // 형식을 제한하지 않는다 — 브라우저마다 EAN 인식 방식이 달라 제한하면 놓치는 경우가 있음
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _done = false;
  String _lastRaw = ''; // 화면에 보여줄 마지막으로 읽힌 값 (문제 확인용)

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String isbn) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(isbn);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue ?? barcode.displayValue ?? '';
      if (raw.isEmpty) continue;
      final isbn = BookLookupService.findIsbnInScan(raw);
      if (isbn != null) {
        _finish(isbn);
        return;
      }
      if (raw != _lastRaw && mounted) setState(() => _lastRaw = raw);
    }
  }

  /// 바코드가 안 읽힐 때: 번호를 직접 입력
  Future<void> _typeManually() async {
    final ctrl = TextEditingController();
    final isbn = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ISBN 직접 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '978로 시작하는 13자리',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('확인')),
        ],
      ),
    );
    ctrl.dispose();
    if (isbn == null || !mounted) return;
    final clean = BookLookupService.cleanIsbn(isbn);
    if (clean == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ISBN 은 10자리 또는 13자리 숫자예요.')));
      return;
    }
    _finish(clean);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('바코드 찍기'),
        actions: [
          IconButton(
            tooltip: '손전등',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
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
                width: 300,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '책 뒷면의 ISBN 바코드(978…)를 네모 안에 맞춰 주세요.\n'
                  '옆의 작은 바코드(부가기호)는 가리지 않아도 돼요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
                if (_lastRaw.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '읽힌 값: $_lastRaw (ISBN 아님)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    minimumSize: const Size(200, 44),
                  ),
                  onPressed: _typeManually,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('번호 직접 입력'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
