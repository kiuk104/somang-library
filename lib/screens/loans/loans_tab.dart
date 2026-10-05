import 'package:flutter/material.dart';

import '../../models/library_user.dart';
import '../../models/loan.dart';
import '../../services/loan_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/place_picker.dart';
import '../../widgets/push_card.dart';
import 'notifications_screen.dart';

/// 대여 — 신청 받기 · 주일 주고받기 · 빌린 책 · 빌려준 책 · 지난 기록
/// loans / notices 는 HomeShell 이 구독해서 내려준다 (탭 배지와 같은 데이터)
class LoansTab extends StatefulWidget {
  final LibraryUser me;
  final List<Loan>? loans; // null: 불러오는 중
  final Object? loansError;
  final List<LibraryNotice> notices;

  const LoansTab({
    super.key,
    required this.me,
    required this.loans,
    required this.loansError,
    required this.notices,
  });

  @override
  State<LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends State<LoansTab> {
  final Set<String> _busy = {}; // 처리 중인 대여 건 (연타 방지)

  String get _uid => widget.me.uid;

  Future<void> _run(Loan loan, Future<void> Function() action,
      {String? done}) async {
    if (!mounted || _busy.contains(loan.id)) return;
    setState(() => _busy.add(loan.id));
    try {
      await action();
      if (mounted && done != null) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, LoanService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy.remove(loan.id));
    }
  }

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('닫기')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _accept(Loan l) async {
    final places = await showAcceptDialog(context, l);
    if (places == null) return;
    await _run(l,
        () => LoanService.accept(l.id,
            handoverPlace: places.handover, returnPlace: places.ret),
        done: '수락했어요. 다가오는 주일에 ${places.handover}에서 건네주세요.');
  }

  Future<void> _reject(Loan l) async {
    if (!await _confirm('신청 거절', '${l.borrowerName}님의 신청을 거절할까요?', '거절')) {
      return;
    }
    await _run(l, () => LoanService.reject(l.id), done: '거절했어요.');
  }

  Future<void> _cancel(Loan l) async {
    if (!await _confirm('대여 취소', '「${l.bookTitle}」 대여를 취소할까요?', '취소하기')) {
      return;
    }
    await _run(l, () => LoanService.cancel(l.id), done: '취소했어요.');
  }

  Future<void> _handover(Loan l) async {
    final owner = l.isOwner(_uid);
    if (!await _confirm(
        '주고받았어요',
        owner
            ? '${l.borrowerName}님에게 「${l.bookTitle}」을(를) 건네줬나요?'
            : '${l.ownerName}님에게 「${l.bookTitle}」을(를) 받았나요?',
        '네, 완료')) {
      return;
    }
    await _run(l, () => LoanService.handover(l.id),
        done: '대여가 시작됐어요. 반납일은 4주 뒤 주일이에요.');
  }

  Future<void> _return(Loan l) async {
    if (!await _confirm('반납 확인',
        '${l.borrowerName}님에게 「${l.bookTitle}」을(를) 돌려받았나요?', '네, 받았어요')) {
      return;
    }
    await _run(l, () => LoanService.returnBook(l.id),
        done: '반납 완료! 책이 다시 서가에 올라갔어요.');
  }

  Future<void> _reschedule(Loan l) async {
    final fields = await showScheduleDialog(context, l);
    if (fields == null) return;
    if (fields.isEmpty) {
      if (mounted) showSnack(context, '바뀐 내용이 없어요.');
      return;
    }
    await _run(l, () => LoanService.reschedule(l.id, fields),
        done: '일정을 바꿨어요. 상대방에게 알려 드렸어요.');
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.notices.where((n) => !n.read).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('대여'),
        actions: [
          IconButton(
            tooltip: '알림',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsScreen(notices: widget.notices),
            )),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.loansError != null) {
      return Center(child: Text('오류: ${widget.loansError}'));
    }
    final loans = widget.loans;
    if (loans == null) {
      return const Center(child: CircularProgressIndicator());
    }

    bool mine(Loan l) => l.isOwner(_uid);
    final incoming =
        loans.where((l) => mine(l) && l.status == LoanStatus.requested).toList();
    final myRequests =
        loans.where((l) => !mine(l) && l.status == LoanStatus.requested).toList();
    final sunday = loans.where((l) => l.status == LoanStatus.accepted).toList();
    final borrowed =
        loans.where((l) => !mine(l) && l.status == LoanStatus.lent).toList();
    final lentOut =
        loans.where((l) => mine(l) && l.status == LoanStatus.lent).toList();
    final past = loans.where((l) => !l.isActive).take(30).toList();

    final sections = <Widget>[
      const PushCard(),
      if (incoming.isNotEmpty) ...[
        _header('신청이 왔어요', incoming.length),
        for (final l in incoming)
          _LoanCard(
            loan: l,
            lines: [
              '${l.borrowerName}님이 빌리고 싶어 해요',
              if (l.handoverPlace.isNotEmpty) '희망 장소: ${l.handoverPlace}',
              if (l.message.isNotEmpty) '"${l.message}"',
            ],
            busy: _busy.contains(l.id),
            actions: [
              _Act('거절', () => _reject(l)),
              _Act('수락', () => _accept(l), primary: true),
            ],
          ),
      ],
      if (sunday.isNotEmpty) ...[
        _header('주일에 주고받기', sunday.length),
        for (final l in sunday)
          _LoanCard(
            loan: l,
            lines: [
              mine(l)
                  ? '${l.borrowerName}님에게 건네주기'
                  : '${l.ownerName}님에게 받기',
              '📅 ${Loan.koWhen(l.handoverDate, l.handoverTime)}',
              '📍 ${l.handoverPlace}',
              if (l.returnPlace.isNotEmpty && l.returnPlace != l.handoverPlace)
                '반납은 ${l.returnPlace}',
            ],
            busy: _busy.contains(l.id),
            actions: [
              _Act('취소', () => _cancel(l)),
              _Act('일정 변경', () => _reschedule(l)),
              _Act('주고받았어요', () => _handover(l), primary: true),
            ],
          ),
      ],
      if (myRequests.isNotEmpty) ...[
        _header('내가 신청한 책', myRequests.length),
        for (final l in myRequests)
          _LoanCard(
            loan: l,
            lines: ['${l.ownerName}님의 응답을 기다리는 중'],
            busy: _busy.contains(l.id),
            actions: [_Act('신청 취소', () => _cancel(l))],
          ),
      ],
      if (borrowed.isNotEmpty) ...[
        _header('빌린 책', borrowed.length),
        for (final l in borrowed)
          _LoanCard(
            loan: l,
            warn: l.isOverdue,
            lines: [
              '${l.ownerName}님의 책',
              '${l.isOverdue ? '⚠️ 반납일 지남' : '반납일'}: ${Loan.koWhen(l.dueDate, l.returnTime)}',
              '📍 반납 장소: ${l.returnPlace.isEmpty ? '정해지지 않음' : l.returnPlace}',
            ],
            busy: _busy.contains(l.id),
            actions: [_Act('반납 일정·장소 변경', () => _reschedule(l))],
          ),
      ],
      if (lentOut.isNotEmpty) ...[
        _header('빌려준 책', lentOut.length),
        for (final l in lentOut)
          _LoanCard(
            loan: l,
            warn: l.isOverdue,
            lines: [
              '${l.borrowerName}님이 읽는 중',
              '${l.isOverdue ? '⚠️ 반납일 지남' : '반납일'}: ${Loan.koWhen(l.dueDate, l.returnTime)}',
              '📍 반납 장소: ${l.returnPlace.isEmpty ? '정해지지 않음' : l.returnPlace}',
            ],
            busy: _busy.contains(l.id),
            actions: [
              _Act('일정 변경', () => _reschedule(l)),
              _Act('돌려받았어요', () => _return(l), primary: true),
            ],
          ),
      ],
      if (incoming.isEmpty &&
          sunday.isEmpty &&
          myRequests.isEmpty &&
          borrowed.isEmpty &&
          lentOut.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            '진행 중인 대여가 없어요.\n서가에서 읽고 싶은 책을 골라 신청해 보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
      if (past.isNotEmpty)
        Card(
          child: ExpansionTile(
            title: Text('지난 기록 (${past.length})'),
            shape: const Border(),
            children: [
              for (final l in past)
                ListTile(
                  dense: true,
                  leading: BookCover(
                      coverUrl: l.bookCover, title: l.bookTitle, width: 28),
                  title: Text(l.bookTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${mine(l) ? '→ ${l.borrowerName}' : '← ${l.ownerName}'} · ${LoanStatus.label(l.status)}'),
                ),
            ],
          ),
        ),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: sections,
        ),
      ),
    );
  }

  Widget _header(String title, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text('$title · $count',
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

class _Act {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _Act(this.label, this.onTap, {this.primary = false});
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final List<String> lines;
  final List<_Act> actions;
  final bool busy;
  final bool warn;

  const _LoanCard({
    required this.loan,
    required this.lines,
    required this.actions,
    required this.busy,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: warn ? theme.colorScheme.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                      coverUrl: loan.bookCover, title: loan.bookTitle, width: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loan.bookTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(line,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (busy)
                const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              else
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final a in actions)
                      a.primary
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
                              onPressed: a.onTap,
                              child: Text(a.label))
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40)),
                              onPressed: a.onTap,
                              child: Text(a.label)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
