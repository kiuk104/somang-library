import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/loan.dart';
import '../../services/loan_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';

/// 전체 대여 현황 (도서관 관리자 전용)
/// 규칙: 관리자(스태프·담당자)는 모든 loans 를 읽을 수 있다. 쓰기는 loanAction 함수만.
/// 반납 확인 대기 → 반납일이 지난 건 → 진행 중 → 지난 기록 순으로 보여 준다.
/// 대여 중인 건을 누르면 관리자가 대신 반납 완료 처리할 수 있다 (loanAction return).
class AdminLoansScreen extends StatefulWidget {
  const AdminLoansScreen({super.key});

  @override
  State<AdminLoansScreen> createState() => _AdminLoansScreenState();
}

class _AdminLoansScreenState extends State<AdminLoansScreen> {
  // 최근 신청 순 300건 (교회 도서관 규모. 정렬만 서버, 나머지는 클라이언트에서 거른다)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('loans')
          .orderBy('requestedAt', descending: true)
          .limit(300)
          .snapshots();

  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _busy = {}; // 처리 중인 대여 건 (연타 방지)

  /// 대여 중인 건을 관리자가 대신 반납 완료 처리
  Future<void> _forceReturn(Loan l) async {
    if (_busy.contains(l.id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('반납 완료 처리'),
        content: Text(
            '「${l.bookTitle}」\n${l.ownerName} → ${l.borrowerName}\n\n'
            '책이 ${l.ownerName}님에게 돌아간 것이 확실한가요?\n'
            '완료하면 책이 다시 서가에 올라가고, 두 분에게 알림이 가요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('닫기')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('반납 완료')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(l.id));
    try {
      await LoanService.returnBook(l.id);
      if (mounted) showSnack(context, '반납 완료로 처리했어요.');
    } catch (e) {
      if (mounted) showSnack(context, LoanService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 반납 예정일에서 며칠 지났는지
  int _daysOver(Loan l) {
    final due = DateTime.tryParse(l.dueDate);
    if (due == null) return 0;
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day).difference(due).inDays;
  }

  /// 신청 후 며칠째 (응답을 기다리는 건 확인용)
  int _daysSince(DateTime? t) =>
      t == null ? 0 : DateTime.now().difference(t).inDays;

  String _detail(Loan l) {
    switch (l.status) {
      case LoanStatus.requested:
        final d = _daysSince(l.requestedAt);
        return d > 0 ? '신청 후 $d일째 응답 대기' : '방금 신청';
      case LoanStatus.accepted:
        return '주고받기 ${Loan.koWhen(l.handoverDate, l.handoverTime)}'
            '${l.handoverPlace.isEmpty ? '' : ' · ${l.handoverPlace}'}';
      case LoanStatus.lent:
        if (l.returnReported) {
          final d = _daysSince(l.returnReportedAt);
          return '빌린 사람이 반납했다고 알림 · ${d > 0 ? '$d일째' : '오늘'} 소장자 확인 없음';
        }
        final base = '반납 ${Loan.koWhen(l.dueDate, l.returnTime)}'
            '${l.returnPlace.isEmpty ? '' : ' · ${l.returnPlace}'}';
        return l.isOverdue ? '$base · ${_daysOver(l)}일 지남' : base;
      default:
        return LoanStatus.label(l.status);
    }
  }

  Widget _tile(Loan l, {bool overdue = false}) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: overdue
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
          : null,
      leading: BookCover(coverUrl: l.bookCover, title: l.bookTitle, width: 36),
      title: Text(l.bookTitle,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${l.ownerName} → ${l.borrowerName}\n${_detail(l)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      // 대여 중인 건만 누를 수 있다 → 대신 반납 완료
      onTap: l.status == LoanStatus.lent ? () => _forceReturn(l) : null,
      trailing: _busy.contains(l.id)
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : Text(l.returnReported ? '확인 대기' : LoanStatus.label(l.status),
              style: TextStyle(
                  fontSize: 12,
                  color: overdue
                      ? theme.colorScheme.error
                      : l.returnReported
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline)),
    );
  }

  Widget _section(String title, List<Widget> tiles) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  tiles[i],
                ],
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('전체 대여 현황')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('오류: ${snapshot.error}');
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final q = _query.trim().toLowerCase();
            final all = snapshot.data!.docs.map(Loan.fromDoc).where((l) {
              if (q.isEmpty) return true;
              return '${l.bookTitle} ${l.ownerName} ${l.borrowerName}'
                  .toLowerCase()
                  .contains(q);
            }).toList();

            final overdue = all.where((l) => l.isOverdue).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate)); // 오래된 순
            // 진행 중: 대여 중 → 주고받기 예정 → 신청 (오래 기다린 신청이 위로)
            int order(Loan l) => switch (l.status) {
                  LoanStatus.lent => 0,
                  LoanStatus.accepted => 1,
                  _ => 2,
                };
            // 빌린 사람은 반납했다는데 소장자 확인이 없는 건 (오래된 순)
            final waiting = all.where((l) => l.returnReported).toList()
              ..sort((a, b) =>
                  a.returnReportedAt!.compareTo(b.returnReportedAt!));
            final active = all
                .where((l) => l.isActive && !l.isOverdue && !l.returnReported)
                .toList()
              ..sort((a, b) {
                final o = order(a).compareTo(order(b));
                if (o != 0) return o;
                final at = a.requestedAt, bt = b.requestedAt;
                if (at == null || bt == null) return 0;
                return at.compareTo(bt);
              });
            final past = all.where((l) => !l.isActive).take(30).toList();
            final activeCount = all.where((l) => l.isActive).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Chip(label: Text('진행 중 $activeCount건')),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('반납 지남 ${overdue.length}건'),
                      backgroundColor: overdue.isEmpty
                          ? null
                          : theme.colorScheme.errorContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '책 제목·소장자·빌린 사람 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          ),
                  ),
                ),
                if (waiting.isNotEmpty || overdue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('대여 중인 책을 누르면 대신 반납 완료 처리할 수 있어요.',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.outline)),
                  ),
                if (waiting.isNotEmpty)
                  _section('반납 확인 대기 (${waiting.length})',
                      [for (final l in waiting) _tile(l)]),
                if (overdue.isNotEmpty)
                  _section('반납 지난 건 (${overdue.length})',
                      [for (final l in overdue) _tile(l, overdue: true)]),
                if (active.isNotEmpty)
                  _section('진행 중 (${active.length})',
                      [for (final l in active) _tile(l)]),
                if (past.isNotEmpty)
                  _section('지난 기록 (최근 ${past.length}건)',
                      [for (final l in past) _tile(l)]),
                if (all.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(q.isEmpty ? '아직 대여 기록이 없어요.' : '찾는 기록이 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
