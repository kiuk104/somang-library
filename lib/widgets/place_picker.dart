import 'package:flutter/material.dart';

import '../models/loan.dart';

/// 주고받는 장소 고르기 — 게마인데잘 / 대여 서재 / 대예배실 앞 / 직접 입력
class PlacePicker extends StatefulWidget {
  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  const PlacePicker({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  static const _custom = '__custom__';
  late String _selected;
  late final TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    final isPreset = LoanPlaces.presets.any((p) => p.name == widget.initial);
    _selected = widget.initial.isEmpty
        ? LoanPlaces.presets.first.name
        : (isPreset ? widget.initial : _custom);
    _customCtrl =
        TextEditingController(text: isPreset ? '' : widget.initial);
    // 처음 값 알려 주기 (빌드 중 setState 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    if (!mounted) return;
    widget.onChanged(
        _selected == _custom ? _customCtrl.text.trim() : _selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = LoanPlaces.presets
        .where((p) => p.name == _selected)
        .map((p) => p.hint)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in LoanPlaces.presets)
              ChoiceChip(
                label: Text(p.name),
                selected: _selected == p.name,
                onSelected: (_) {
                  setState(() => _selected = p.name);
                  _notify();
                },
              ),
            ChoiceChip(
              label: const Text('직접 입력'),
              selected: _selected == _custom,
              onSelected: (_) {
                setState(() => _selected = _custom);
                _notify();
              },
            ),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(hint,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          ),
        if (_selected == _custom)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _customCtrl,
              maxLength: 50,
              autofocus: true,
              onChanged: (_) => _notify(),
              decoration: const InputDecoration(
                hintText: '예: 1층 로비, 주차장 입구',
                counterText: '',
              ),
            ),
          ),
      ],
    );
  }
}

/// 대여 신청 창 — (받고 싶은 곳, 메모) 또는 취소 시 null
Future<({String place, String message})?> showRequestDialog(
    BuildContext context, String bookTitle) {
  var place = '';
  final msgCtrl = TextEditingController();
  return showDialog<({String place, String message})>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('「$bookTitle」 빌리기'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlacePicker(
              label: '받고 싶은 곳',
              initial: '',
              onChanged: (v) => place = v,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '소장자에게 한마디 (선택)',
                hintText: '예: 2주 정도 읽고 돌려드릴게요!',
              ),
            ),
            Text('소장자가 수락하면 다가오는 주일에 주고받아요.',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(ctx).colorScheme.outline)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(
          onPressed: () => Navigator.pop(
              ctx, (place: place, message: msgCtrl.text.trim())),
          child: const Text('신청하기'),
        ),
      ],
    ),
  ); // msgCtrl 은 닫힘 애니메이션 중에도 쓰이므로 dispose 하지 않는다
}

/// 수락 창 — (전달 장소, 반납 장소)
Future<({String handover, String ret})?> showAcceptDialog(
    BuildContext context, Loan loan) {
  var handover = loan.handoverPlace;
  var ret = '';
  var sameReturn = true;
  return showDialog<({String handover, String ret})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('대여 수락'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${loan.borrowerName}님에게 「${loan.bookTitle}」을(를) 빌려줘요.'),
              if (loan.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('"${loan.message}"',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),
              PlacePicker(
                label: '건네줄 곳',
                initial: loan.handoverPlace,
                onChanged: (v) => handover = v,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sameReturn,
                onChanged: (v) => setLocal(() => sameReturn = v ?? true),
                title: const Text('반납도 같은 곳에서'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (!sameReturn)
                PlacePicker(
                  label: '돌려받을 곳',
                  initial: '',
                  onChanged: (v) => ret = v,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          FilledButton(
            onPressed: () {
              if (handover.isEmpty || (!sameReturn && ret.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('장소를 골라 주세요. (직접 입력은 내용을 적어 주세요)')));
                return;
              }
              Navigator.pop(ctx,
                  (handover: handover, ret: sameReturn ? handover : ret));
            },
            child: const Text('수락하기'),
          ),
        ],
      ),
    ),
  );
}

/// 반납 장소 바꾸기 창
Future<String?> showReturnPlaceDialog(BuildContext context, Loan loan) {
  var place = loan.returnPlace;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('반납 장소 바꾸기'),
      content: PlacePicker(
        label: '돌려줄 곳',
        initial: loan.returnPlace,
        onChanged: (v) => place = v,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        FilledButton(
          onPressed: () {
            if (place.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('장소를 입력해 주세요.')));
              return;
            }
            Navigator.pop(ctx, place);
          },
          child: const Text('바꾸기'),
        ),
      ],
    ),
  );
}
