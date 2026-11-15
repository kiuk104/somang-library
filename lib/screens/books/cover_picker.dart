import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import '../../widgets/book_cover.dart';

/// web/clipboard_image.js — 클립보드 그림(줄인 JPEG 바이트) 또는 글자, 없으면 null
@JS('somangPasteImage')
external JSPromise<JSAny?> _pasteImage();

/// 표지 바꾸기 메뉴에서 고른 것
enum CoverAction { camera, gallery, web, paste, isbn, clear }
// paste: 복사한 이미지 또는 이미지 주소 붙여넣기 (대화상자)

/// 표지 바꾸기 — 사진 찍기·앨범·인터넷에서 찾기·주소 붙여넣기·ISBN 으로 찾기·지우기
/// 고른 동작을 돌려준다 (닫으면 null). 실제 처리는 [CoverTools] 와 등록 화면이 한다.
Future<CoverAction?> showCoverMenu(
  BuildContext context, {
  required bool hasCover,
  required bool hasIsbn,
}) {
  return showModalBottomSheet<CoverAction>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) {
      Widget item(CoverAction a, IconData icon, String title, [String? sub]) =>
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: sub == null ? null : Text(sub),
            onTap: () => Navigator.pop(context, a),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(CoverAction.camera, Icons.photo_camera_outlined, '표지 사진 찍기',
                '책 앞면이 화면에 꽉 차게 찍어 주세요'),
            item(CoverAction.gallery, Icons.photo_library_outlined, '앨범에서 고르기'),
            item(CoverAction.web, Icons.travel_explore, '인터넷에서 찾기',
                '구글 이미지에서 표지를 길게 눌러 "이미지 복사" → 돌아와서 붙여넣기'),
            item(CoverAction.paste, Icons.content_paste, '복사한 이미지 붙여넣기',
                '이미지 또는 이미지 주소'),
            if (hasIsbn)
              item(CoverAction.isbn, Icons.search, 'ISBN 으로 다시 찾기'),
            if (hasCover)
              item(CoverAction.clear, Icons.delete_outline, '표지 지우기',
                  '기본 표지(제목 글자)로 돌아가요'),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class CoverTools {
  /// 표지 사진 고르기 → 줄이고 압축해서 함수(uploadBookCover)로 올린 뒤 주소를 돌려준다.
  /// 고르지 않고 닫으면 null. 실패하면 예외 (메시지는 한국어)
  static Future<String?> pickAndUpload(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      // 표지는 작게 보이므로 600px 이면 충분 (아이폰 메모리·업로드 속도)
      maxWidth: 600,
      maxHeight: 900,
      imageQuality: 80,
    );
    if (photo == null) return null;
    return upload(await photo.readAsBytes());
  }

  /// 그림 바이트를 함수(uploadBookCover)로 올리고 공개 주소를 돌려준다
  static Future<String> upload(Uint8List bytes) async {
    if (bytes.length > 800 * 1024) {
      throw '사진이 너무 커요. 다시 찍어 주세요.';
    }
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('uploadBookCover')
          .call({'image': base64Encode(bytes)})
          .timeout(const Duration(seconds: 40));
      final url = (res.data as Map)['url']?.toString() ?? '';
      if (url.isEmpty) throw '올리지 못했어요.';
      return url;
    } on FirebaseFunctionsException catch (e) {
      // 함수가 아직 배포 안 됐으면 not-found
      throw e.code == 'not-found'
          ? '사진 올리기 기능(uploadBookCover)이 아직 배포되지 않았어요.'
          : '${e.message ?? '올리지 못했어요.'} [${e.code}]';
    }
  }

  /// 클립보드 붙여넣기 — 그림이면 줄여서 올린 주소, 이미지 주소(글자)면 그 주소.
  /// 클립보드가 비었거나 쓸 수 없는 글자면 null. 실패하면 예외 (한국어 메시지)
  static Future<String?> pasteFromClipboard() async {
    JSAny? got;
    try {
      await _ensureScript();
      got = await _pasteImage().toDart;
    } catch (e) {
      final msg = '$e'.replaceFirst(RegExp(r'^(Error|JSError|Exception):\s*'), '');
      throw msg.isEmpty ? '붙여넣지 못했어요.' : msg;
    }
    if (got == null) return null;
    if (got.isA<JSString>()) return cleanImageUrl((got as JSString).toDart);
    if (got.isA<JSUint8Array>()) return upload((got as JSUint8Array).toDart);
    return null;
  }

  /// clipboard_image.js 가 없으면(브라우저가 예전 index.html 을 기억하는 경우) 직접 불러온다
  static Future<void> _ensureScript() async {
    if (globalContext.has('somangPasteImage')) return;
    final done = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'clipboard_image.js?v=${DateTime.now().millisecondsSinceEpoch}';
    script.onload = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    script.onerror = ((web.Event _) {
      if (!done.isCompleted) done.completeError('붙여넣기 기능을 불러오지 못했어요.');
    }).toJS;
    web.document.head!.append(script);
    await done.future.timeout(const Duration(seconds: 10));
  }

  /// 구글 이미지 검색을 새 탭으로 연다 (제목 + 저자 + 'cover')
  static void openImageSearch(String title, String author) {
    final q = [title, author, 'cover'].where((s) => s.trim().isNotEmpty).join(' ');
    web.window.open(
      'https://www.google.com/search?tbm=isch&q=${Uri.encodeQueryComponent(q)}',
      '_blank',
    );
  }

  /// 붙여넣은 주소 정리 — 구글 이미지 결과 페이지 주소(imgres?imgurl=…)면 실제 그림 주소를 꺼낸다.
  /// 그림 주소가 아니면 null
  static String? cleanImageUrl(String raw) {
    var s = raw.trim();
    final uri = Uri.tryParse(s);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    final inner = uri.queryParameters['imgurl'] ?? uri.queryParameters['mediaurl'];
    if (inner != null && inner.startsWith('http')) s = inner;
    s = s.replaceFirst(RegExp(r'^http://'), 'https://');
    return s.length <= 1000 ? s : null; // 규칙: coverUrl 1000자
  }
}

/// 이미지 주소 붙여넣기 — 미리 보기로 확인하고 고른다. 고른 주소(또는 null)
Future<String?> showCoverUrlDialog(BuildContext context, {String title = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CoverUrlDialog(title: title),
  );
}

class _CoverUrlDialog extends StatefulWidget {
  final String title;
  const _CoverUrlDialog({required this.title});

  @override
  State<_CoverUrlDialog> createState() => _CoverUrlDialogState();
}

class _CoverUrlDialogState extends State<_CoverUrlDialog> {
  final _ctrl = TextEditingController();
  String? _url; // 정리된 주소 (미리 보기용)
  bool _busy = false; // 붙여넣은 그림 올리는 중
  String _error = '';

  /// '붙여넣기' 버튼 — 복사한 그림이면 올리고, 주소면 칸에 채운다 (버튼을 눌러야 브라우저가 허락한다)
  Future<void> _pasteAny() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final got = await CoverTools.pasteFromClipboard();
      if (!mounted) return;
      if (got == null) {
        setState(() => _error = '복사한 이미지나 이미지 주소가 없어요.');
      } else {
        _ctrl.text = got;
        _onChanged(got);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) =>
      setState(() => _url = CoverTools.cleanImageUrl(v));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('표지 붙여넣기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _pasteAny,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.content_paste),
                label: Text(_busy ? '올리는 중…' : '복사한 이미지 붙여넣기'),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_error,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '또는 이미지 주소',
                hintText: 'https://…',
              ),
            ),
            const SizedBox(height: 16),
            if (_url != null)
              BookCover(coverUrl: _url!, title: widget.title, width: 100)
            else
              Text(
                '구글 이미지에서 표지를 길게 누르고\n"이미지 복사"(또는 "이미지 주소 복사")를 고른 뒤\n위 버튼을 누르세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            if (_url != null) ...[
              const SizedBox(height: 8),
              Text('표지가 보이면 "이 표지 쓰기"를 누르세요.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _url == null ? null : () => Navigator.pop(context, _url),
          child: const Text('이 표지 쓰기'),
        ),
      ],
    );
  }
}
