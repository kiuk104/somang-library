import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/library_user.dart';
import '../models/loan.dart';
import '../services/book_service.dart';
import '../services/loan_service.dart';

/// 내 신청 가능 권수 — 지금 신청·대여 중인 책 / 한도
/// 한도는 내가 공개한 책이 많을수록 늘어난다 (도서관 관리자는 무제한).
class QuotaCard extends StatefulWidget {
  final LibraryUser me;
  const QuotaCard({super.key, required this.me});

  @override
  State<QuotaCard> createState() => _QuotaCardState();
}

class _QuotaCardState extends State<QuotaCard> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _books =
      BookService.watchMine(widget.me.uid);
  late final Stream<List<Loan>> _loans = LoanService.watchMine(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.me.isLibraryAdmin) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.all_inclusive),
          title: Text('신청 가능 권수'),
          subtitle: Text('도서관 관리자는 제한 없이 신청할 수 있어요'),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _books,
      builder: (context, booksSnap) {
        return StreamBuilder<List<Loan>>(
          stream: _loans,
          builder: (context, loansSnap) {
            if (!booksSnap.hasData || !loansSnap.hasData) {
              return const SizedBox.shrink();
            }
            final shared = booksSnap.data!.docs
                .map(Book.fromDoc)
                .where((b) => b.status != BookStatus.hidden)
                .length;
            final active = loansSnap.data!
                .where((l) => l.borrowerId == widget.me.uid && l.isActive)
                .length;
            final penalty = LoanQuota.penaltyFor(loansSnap.data!
                .where((l) => l.borrowerId == widget.me.uid));
            final limit = LoanQuota.limitFor(shared);
            final next = LoanQuota.booksToNext(shared);
            final full = active >= limit;
            final warn = penalty.overdueTitle != null
                ? '반납일이 지난 책이 있어 새로 신청할 수 없어요.\n「${penalty.overdueTitle}」을(를) 먼저 반납해 주세요.'
                : (penalty.blockedUntil != null
                    ? '늦게 반납해서 ${Loan.koDate(penalty.blockedUntil!)}까지 새로 신청할 수 없어요.'
                    : null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (warn != null)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                          color: theme.colorScheme.onErrorContainer),
                      title: Text('연체 페널티',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onErrorContainer)),
                      subtitle: Text(warn,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer)),
                    ),
                  ),
                _quotaTile(theme, shared, active, limit, next, full),
              ],
            );
          },
        );
      },
    );
  }

  Widget _quotaTile(ThemeData theme, int shared, int active, int limit,
      int? next, bool full) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.bookmarks_outlined,
            color: full ? theme.colorScheme.error : null),
        title: Text('신청 가능 $limit권 중 $active권 사용'),
        subtitle: Text(
          '공개한 책 $shared권 · '
          '${next == null ? '최대 한도예요' : '$next권 더 공개하면 ${limit + 1}권까지 신청할 수 있어요'}',
        ),
      ),
    );
  }
}
