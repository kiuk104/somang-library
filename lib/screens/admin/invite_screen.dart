import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/invite_service.dart';
import '../../widgets/page_frame.dart';

/// 교인 초대 링크 만들기 + 만든 링크 목록 (도서관 관리자 전용)
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  int _maxUses = 30;
  int _days = 14;
  bool _busy = false;
  String? _newCode;

  // 최근 초대 20개 (where 없이 orderBy 하나만 → 복합 인덱스 불필요)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _invites =
      FirebaseFirestore.instance
          .collection('invites')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();

  final _dateFmt = DateFormat('M월 d일');

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final result = await InviteService.create(maxUses: _maxUses, days: _days);
      if (mounted) setState(() => _newCode = result.code);
    } catch (e) {
      if (mounted) showSnack(context, InviteService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(
      text: '소망 도서관에 초대합니다 📚\n${InviteService.linkFor(code)}\n(초대 코드: $code)',
    ));
    if (mounted) showSnack(context, '초대 문구를 복사했어요. 카톡방에 붙여 넣으세요!');
  }

  Future<void> _toggleDisabled(
      DocumentReference<Map<String, dynamic>> ref, bool disabled) async {
    try {
      await ref.update({'disabled': !disabled});
    } catch (e) {
      if (mounted) showSnack(context, '변경하지 못했어요. ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('교인 초대 링크')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('새 링크', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _maxUses,
                            decoration:
                                const InputDecoration(labelText: '사용 가능 인원'),
                            items: const [5, 10, 30, 100]
                                .map((n) => DropdownMenuItem(
                                    value: n, child: Text('$n명')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _maxUses = v ?? _maxUses),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _days,
                            decoration:
                                const InputDecoration(labelText: '유효 기간'),
                            items: const [7, 14, 30, 90]
                                .map((n) => DropdownMenuItem(
                                    value: n, child: Text('$n일')))
                                .toList(),
                            onChanged: (v) => setState(() => _days = v ?? _days),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.add_link),
                      label: const Text('링크 만들기'),
                    ),
                    if (_newCode != null) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        InviteService.linkFor(_newCode!),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _copy(_newCode!),
                        icon: const Icon(Icons.copy),
                        label: const Text('초대 문구 복사'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('만든 링크',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _invites,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('오류: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Text('아직 만든 링크가 없어요.',
                      style: TextStyle(color: theme.colorScheme.outline));
                }
                return Card(
                  child: Column(
                    children: [
                      for (final doc in docs) _inviteTile(doc),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _inviteTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final used = (d['useCount'] as num?)?.toInt() ?? 0;
    final max = (d['maxUses'] as num?)?.toInt() ?? 0;
    final disabled = d['disabled'] == true;
    final expires = d['expiresAt'] is Timestamp
        ? (d['expiresAt'] as Timestamp).toDate()
        : null;
    final usedUp = max > 0 && used >= max;
    final expired =
        usedUp || (expires != null && expires.isBefore(DateTime.now()));
    final status = disabled
        ? '중지됨'
        : usedUp
            ? '다 씀'
            : expired
            ? '기간 지남'
            : expires == null
                ? '기한 없음'
                : '${_dateFmt.format(expires)}까지';

    return ListTile(
      title: Text(doc.id,
          style: TextStyle(
            fontFamily: 'monospace',
            decoration: (disabled || expired) ? TextDecoration.lineThrough : null,
          )),
      subtitle: Text('$used / $max명 사용 · $status'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '초대 문구 복사',
            icon: const Icon(Icons.copy),
            onPressed: (disabled || expired) ? null : () => _copy(doc.id),
          ),
          IconButton(
            tooltip: disabled ? '다시 사용' : '사용 중지',
            icon: Icon(disabled ? Icons.play_arrow : Icons.block),
            onPressed: () => _toggleDisabled(doc.reference, disabled),
          ),
        ],
      ),
    );
  }
}
