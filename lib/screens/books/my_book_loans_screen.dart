import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../models/loan.dart';
import '../../services/book_service.dart';
import '../../services/loan_service.dart';
import '../../widgets/book_cover.dart';

/// 내 책 대여 현황 — 내가 소장한 책마다 "누가 신청했고, 누가 빌려 갔고, 언제 돌아오는지"
/// 그리고 지난 대여 기록까지 한눈에 본다. (보기 전용 — 수락·반납 처리는 "대여" 탭에서)
class MyBookLoansScreen extends StatefulWidget {
  final LibraryUser me;
  const MyBookLoansScreen({super.key, required this.me});

  static void open(BuildContext context, LibraryUser me) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MyBookLoansScreen(me: me)),
    );
  }

  @override
  State<MyBookLoansScreen> createState() => _MyBookLoansScreenState();
}

class _MyBookLoansScreenState extends State<MyBookLoansScreen> {
  List<Book>? _books;
  List<Loan>? _loans;
  Object? _error;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    final uid = widget.me.uid;
    _subs.add(BookService.watchMine(uid).listen(
      (s) => setState(() {
        _books = BookService.sortNewest(s.docs.map(Book.fromDoc));
      }),
      onError: (Object e) => setState(() => _error = e),
    ));
    _subs.add(LoanService.watchMine(uid).listen(
      (l) => setState(() => _loans = l.where((x) => x.ownerId == uid).toList()),
      onError: (Object e) => setState(() => _error = e),
    ));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 책 대여 현황')),
      body: _body(context),
    );
  }

  /// 정렬 우선순위: 처리할 일이 있는 책이 위로
  int _rank(List<Loan> loans) {
    if (loans.any((l) => l.status == LoanStatus.requested)) return 0;
    if (loans.any((l) => l.status == LoanStatus.accepted)) return 1;
    if (loans.any((l) => l.isOverdue)) return 2;
    if (loans.any((l) => l.status == LoanStatus.lent)) return 3;
    if (loans.isNotEmpty) return 4;
    return 5;
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) return Center(child: Text('오류: $_error'));
    final books = _books, loans = _loans;
    if (books == null || loans == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('아직 등록한 책이 없어요.\n책을 등록하면 여기서 대여 현황을 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline)),
        ),
      );
    }

    final byBook = <String, List<Loan>>{};
    for (final l in loans) {
      byBook.putIfAbsent(l.bookId, () => []).add(l);
    }
    final entries = [
      for (var i = 0; i < books.length; i++)
        (i: i, book: books[i], loans: byBook[books[i].id] ?? const <Loan>[]),
    ]..sort((a, b) {
        final r = _rank(a.loans).compareTo(_rank(b.loans));
        return r != 0 ? r : a.i.compareTo(b.i);
      });

    int count(bool Function(Loan) f) => loans.where(f).length;
    final waiting = count((l) => l.status == LoanStatus.requested);
    final sunday = count((l) => l.status == LoanStatus.accepted);
    final lent = count((l) => l.status == LoanStatus.lent);
    final overdue = count((l) => l.isOverdue);
    final totalDone =
        count((l) => l.status == LoanStatus.returned || l.status == LoanStatus.lent);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                _stat(context, '신청 대기', waiting, highlight: waiting > 0),
                _stat(context, '주고받기 예정', sunday, highlight: sunday > 0),
                _stat(context, '대여 중', lent),
                _stat(context, '연체', overdue, danger: overdue > 0),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                '내 책 ${books.length}권 · 지금까지 $totalDone번 빌려 갔어요\n'
                '수락·반납 처리는 "대여" 탭에서 해요.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
              ),
            ),
            for (final e in entries) _BookLoansCard(book: e.book, loans: e.loans),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int n,
      {bool highlight = false, bool danger = false}) {
    final cs = Theme.of(context).colorScheme;
    final bg = danger
        ? cs.errorContainer
        : highlight
            ? cs.primaryContainer
            : cs.surfaceContainerHighest;
    final fg = danger
        ? cs.onErrorContainer
        : highlight
            ? cs.onPrimaryContainer
            : cs.onSurfaceVariant;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$n',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _BookLoansCard extends StatelessWidget {
  final Book book;
  final List<Loan> loans; // 이 책의 대여 건 전부 (정렬 전)

  const _BookLoansCard({required this.book, required this.loans});

  static String _day(DateTime? d) => d == null ? '' : '${d.month}/${d.day}';

  static int _order(Loan l) {
    switch (l.status) {
      case LoanStatus.requested:
        return 0;
      case LoanStatus.accepted:
        return 1;
      case LoanStatus.lent:
        return 2;
      default:
        return 3;
    }
  }

  static DateTime? _when(Loan l) => l.returnedAt ?? l.updatedAt ?? l.requestedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final active = loans.where((l) => l.isActive).toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    final past = loans.where((l) => !l.isActive).toList()
      ..sort((a, b) {
        final at = _when(a), bt = _when(b);
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    final doneCount = loans
        .where((l) =>
            l.status == LoanStatus.returned || l.status == LoanStatus.lent)
        .length;
    final borrowers = loans
        .where((l) =>
            l.status == LoanStatus.returned || l.status == LoanStatus.lent)
        .map((l) => l.borrowerId)
        .toSet()
        .length;
    final hasOverdue = active.any((l) => l.isOverdue);

    final summary = doneCount == 0
        ? '아직 빌려 간 사람이 없어요'
        : '$borrowers명이 총 $doneCount번 빌려 갔어요';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: hasOverdue ? cs.errorContainer : null,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('${book.id}-${active.length}'),
        initiallyExpanded: active.isNotEmpty,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading:
            BookCover(coverUrl: book.coverUrl, title: book.title, width: 40),
        title: Text(book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              BookStatusChip(status: book.status),
              Text(summary,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        children: [
          if (active.isEmpty && past.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('신청도, 대여 기록도 아직 없어요.',
                    style: TextStyle(color: cs.outline)),
              ),
            ),
          for (final l in active) _activeRow(context, l),
          if (past.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text('지난 기록 ${past.length}건',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.outline)),
            ),
            for (final l in past) _pastRow(context, l),
          ],
        ],
      ),
    );
  }

  Widget _activeRow(BuildContext context, Loan l) {
    final cs = Theme.of(context).colorScheme;
    late final IconData icon;
    late final String head;
    final lines = <String>[];

    switch (l.status) {
      case LoanStatus.requested:
        icon = Icons.mark_email_unread_outlined;
        head = '${l.borrowerName}님이 신청했어요';
        if (l.requestedAt != null) lines.add('신청일 ${_day(l.requestedAt)}');
        if (l.handoverPlace.isNotEmpty) lines.add('희망 장소: ${l.handoverPlace}');
        if (l.message.isNotEmpty) lines.add('"${l.message}"');
        break;
      case LoanStatus.accepted:
        icon = Icons.event_available_outlined;
        head = '${l.borrowerName}님에게 건네줄 예정';
        lines.add('📅 ${Loan.koWhen(l.handoverDate, l.handoverTime)}');
        if (l.handoverPlace.isNotEmpty) lines.add('📍 ${l.handoverPlace}');
        break;
      default: // lent
        icon = Icons.menu_book_outlined;
        head = '${l.borrowerName}님이 읽는 중';
        if (l.isOverdue) {
          final days = DateTime.now()
              .difference(DateTime.tryParse(l.dueDate) ?? DateTime.now())
              .inDays;
          lines.add('⚠️ 반납일이 $days일 지났어요 (${Loan.koDate(l.dueDate)})');
        } else {
          lines.add('반납 예정: ${Loan.koWhen(l.dueDate, l.returnTime)}');
        }
        lines.add(
            '📍 반납 장소: ${l.returnPlace.isEmpty ? '정해지지 않음' : l.returnPlace}');
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: l.isOverdue ? cs.error : cs.outlineVariant, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: l.isOverdue ? cs.error : cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(head, style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final t in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(t,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastRow(BuildContext context, Loan l) {
    final cs = Theme.of(context).colorScheme;
    var label = LoanStatus.label(l.status);
    final r = l.returnedAt;
    if (l.status == LoanStatus.returned && r != null && l.dueDate.isNotEmpty) {
      final ret = Loan.ymdOf(r);
      if (ret.compareTo(l.dueDate) > 0) {
        final late =
            DateTime.parse(ret).difference(DateTime.parse(l.dueDate)).inDays;
        label = '$label · $late일 늦게 반납';
      }
    }
    final when = _day(_when(l));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${l.borrowerName} · $label',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          if (when.isNotEmpty)
            Text(when, style: TextStyle(fontSize: 12, color: cs.outline)),
        ],
      ),
    );
  }
}
