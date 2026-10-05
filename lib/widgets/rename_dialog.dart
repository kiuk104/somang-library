import 'package:flutter/material.dart';

/// 이름 입력 대화상자 — 바꿀 이름을 돌려준다 (취소하거나 그대로면 null)
Future<String?> showRenameDialog(BuildContext context,
    {required String current, String title = '이름 수정'}) {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = ctrl.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        Navigator.pop(ctx, (v.isEmpty || v == current) ? null : v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(
            labelText: '이름 (실명)',
            helperText: '책·대여 기록에 보이는 이름도 함께 바뀌어요',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: submit, child: const Text('저장')),
        ],
      );
    },
  ).whenComplete(ctrl.dispose);
}
