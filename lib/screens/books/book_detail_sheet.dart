import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/friendship.dart';
import '../../models/library_user.dart';
import '../../models/loan.dart';
import '../../services/book_service.dart';
import '../../services/friend_service.dart';
import '../../services/loan_service.dart';
import '../../widgets/place_picker.dart';
import '../../widgets/book_cover.dart';
import 'book_form_screen.dart';
import 'book_info_sheet.dart';

/// 책 자세히 보기 (아래에서 올라오는 시트)
/// - 내 책이면: 대여 가능/쉼 전환, 수정, 삭제
/// - 남의 책이면: 대여 신청 (다음 단계)
Future<void> showBookDetail(BuildContext context, Book book, LibraryUser me) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _BookDetail(book: book, me: me),
  );
}

class _BookDetail extends StatefulWidget {
  final Book book;
  final LibraryUser me;
  const _BookDetail({required this.book, required this.me});

  @override
  State<_BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends State<_BookDetail> {
  bool _busy = false;
  bool _showInfo = false; // true 면 같은 시트 안에서 "책 정보" 화면을 보여준다
  late final Stream<List<Friendship>> _friends =
      FriendService.watchMine(widget.me.uid);
  late final Stream<List<WaitEntry>> _waits =
      LoanService.watchMyWaits(widget.me.uid);

  Book get book => widget.book;
  LibraryUser get me => widget.me;
  bool get _mine => book.ownerId == me.uid;

  /// 시트를 닫고 결과 메시지를 보여준다 (시트 위에서는 스낵바가 가려지므로)
  void _closeWith(ScaffoldMessengerState messenger, String? message) {
    if (mounted) Navigator.of(context).pop();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final next = book.isAvailable ? BookStatus.hidden : BookStatus.available;
    try {
      await BookService.setStatus(book.id, next);
      _closeWith(messenger,
          next == BookStatus.available ? '다시 빌려줄 수 있게 했어요.' : '잠시 대여를 쉬어요.');
    } catch (e) {
      _closeWith(messenger, '바꾸지 못했어요. ($e)');
    }
  }

  /// 대여 신청 (받고 싶은 곳 + 메모)
  Future<void> _request() async {
    if (_busy) return;
    final input =
        await showRequestDialog(context, book.title, gift: book.giveaway);
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LoanService.request(book.id,
          handoverPlace: input.place, message: input.message);
      _closeWith(messenger,
          '신청했어요! ${book.ownerName}님이 수락하면 알려 드릴게요. (대여 탭에서 확인)');
    } catch (e) {
      _closeWith(messenger, LoanService.messageFor(e));
    }
  }

  /// 대기 신청 / 취소 — 책이 나오면 알림
  Future<void> _toggleWait(bool waiting) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (waiting) {
        await LoanService.unwait(book.id);
        _closeWith(messenger, '대기를 취소했어요.');
      } else {
        await LoanService.wait(book.id);
        _closeWith(messenger,
            '대기 신청했어요. 책이 나오면 알려 드릴게요. (대여 탭에서 확인)');
      }
    } catch (e) {
      _closeWith(messenger, LoanService.messageFor(e));
    }
  }

  /// 이미 신청·대여 중인 책이면 "대기 신청" 버튼
  Widget _waitButton() {
    final waitable = book.status == BookStatus.requested ||
        book.status == BookStatus.reserved ||
        book.status == BookStatus.lent;
    if (!waitable) return const SizedBox.shrink();
    return StreamBuilder<List<WaitEntry>>(
      stream: _waits,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final waiting = snap.data!.any((w) => w.bookId == book.id);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _toggleWait(waiting),
            icon: Icon(waiting
                ? Icons.notifications_active
                : Icons.notifications_none),
            label: Text(waiting
                ? '대기 중 · 누르면 취소'
                : '대기 신청 · 나오면 알려 드려요'),
          ),
        );
      },
    );
  }

  /// 소장자에게 친구 신청 / 받은 신청 수락
  Future<void> _friendAction(FriendRelation rel) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (rel == FriendRelation.receivedRequest) {
        await FriendService.accept(book.ownerId);
        _closeWith(messenger, '${book.ownerName}님과 친구가 되었어요!');
      } else {
        final r = await FriendService.request(book.ownerId);
        _closeWith(
            messenger,
            r == 'accepted'
                ? '${book.ownerName}님과 친구가 되었어요!'
                : '${book.ownerName}님께 친구 신청을 보냈어요.');
      }
    } catch (e) {
      _closeWith(messenger, FriendService.messageFor(e));
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('책을 삭제할까요?'),
        content: Text('"${book.title}" 을(를) 서가에서 뺍니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BookService.delete(book.id);
      _closeWith(messenger, '삭제했어요.');
    } catch (e) {
      _closeWith(messenger, '삭제하지 못했어요. ($e)');
    }
  }

  /// 기증하기 켜기·끄기 — 켜 두면 서가에 "기증"으로 보이고, 신청이 오면 대여와 같은 절차로 기증한다
  Future<void> _toggleGiveaway() async {
    if (_busy) return;
    final on = !book.giveaway;
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이 책을 기증할까요?'),
          content: Text('"${book.title}" 이(가) 서가에 "기증" 책으로 표시돼요.\n\n'
              '받고 싶은 분이 신청하면 대여와 똑같이 수락 → 주일에 주고받기로 진행되고, '
              '건네준 뒤에는 그분의 책이 돼요. 신청이 오기 전에는 언제든 취소할 수 있어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('기증하기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BookService.setGiveaway(book.id, on);
      _closeWith(messenger,
          on ? '기증 책으로 올렸어요. 신청이 오면 알려 드릴게요.' : '기증을 취소했어요. 다시 대여용 책이에요.');
    } catch (e) {
      _closeWith(messenger, '바꾸지 못했어요. ($e)');
    }
  }

  /// 기증 되돌리기 (도서관 관리자) — 기증한 사람의 책으로 돌아간다
  Future<void> _revertDonation() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기증을 되돌릴까요?'),
        content: Text('"${book.title}" 을(를) 다시 ${book.donatedByName}님의 책으로 돌려요. '
            '두 분께 알림이 가요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('되돌리기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await BookService.revertDonation(book.id);
      _closeWith(messenger, '기증을 되돌렸어요. 소장자는 다시 $name님이에요.');
    } catch (e) {
      _closeWith(messenger, BookService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [book.author, book.publisher]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showInfo
          ? SingleChildScrollView(
              key: const ValueKey('info'),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: BookInfoView(
                book: book,
                onBack: () => setState(() => _showInfo = false),
              ),
            )
          : _detailBody(theme, meta),
    );
  }

  Widget _detailBody(ThemeData theme, String meta) {
    return SingleChildScrollView(
      key: const ValueKey('detail'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(coverUrl: book.coverUrl, title: book.title, width: 96),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(meta,
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        BookStatusChip(status: book.status),
                        if (book.giveaway) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.card_giftcard,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 2),
                          Text('기증',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary)),
                        ],
                        if (book.friendsOnly) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.people_outline,
                              size: 16, color: theme.colorScheme.outline),
                          const SizedBox(width: 2),
                          Text('친구 공개',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.outline)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _mine ? '내 책' : '소장: ${book.ownerName}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (book.isDonated) ...[
                      const SizedBox(height: 2),
                      Text('기증: ${book.donatedByName}',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (book.note.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(book.note),
              ),
            ),
          ],
          if (book.isbn.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('ISBN ${book.isbn}',
                style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => setState(() => _showInfo = true),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('책 정보 보기'),
          ),
          const SizedBox(height: 12),

          if (_mine) ...[
            if (book.isOwnerEditable) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggle,
                icon: Icon(book.isAvailable
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline),
                label: Text(book.isAvailable
                    ? '잠시 대여 쉬기'
                    : '다시 빌려주기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  // 시트를 닫으면 이 context 는 사라지므로 Navigator 를 먼저 잡아 둔다
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) => BookFormScreen(me: me, editing: book),
                  ));
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('정보 수정'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggleGiveaway,
                icon: Icon(book.giveaway
                    ? Icons.undo
                    : Icons.card_giftcard_outlined),
                label: Text(book.giveaway ? '기증 취소 (다시 대여용으로)' : '기증하기'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                label: Text('삭제',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ] else
              Text('대여가 진행 중이라 지금은 수정할 수 없어요.\n"대여" 탭에서 관리해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.outline)),
          ] else ...[
            FilledButton.icon(
              onPressed: book.isAvailable && !_busy ? _request : null,
              icon: Icon(book.giveaway
                  ? Icons.card_giftcard_outlined
                  : Icons.send_outlined),
              label: Text(book.isAvailable
                  ? (book.giveaway ? '기증 신청 · 받고 싶어요' : '대여 신청')
                  : '지금은 신청할 수 없어요 · ${BookStatus.label(book.status)}'),
            ),
            _waitButton(),
          ],
          // 도서관 관리자: 기증받은 책이면 기증을 되돌릴 수 있다 (대여 진행 중에는 안 됨)
          if (me.isLibraryAdmin && book.isDonated && book.isOwnerEditable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _busy ? null : _revertDonation,
                icon: const Icon(Icons.undo),
                label: const Text('기증 되돌리기 (관리자)'),
              ),
            ),
          if (!_mine)
            StreamBuilder<List<Friendship>>(
              stream: _friends,
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final rel =
                    FriendService.relationTo(snap.data!, book.ownerId);
                switch (rel) {
                  case FriendRelation.friend:
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${book.ownerName}님과 친구예요',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline)),
                    );
                  case FriendRelation.sentRequest:
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${book.ownerName}님께 친구 신청을 보냈어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline)),
                    );
                  case FriendRelation.receivedRequest:
                  case FriendRelation.none:
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _friendAction(rel),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: Text(rel == FriendRelation.receivedRequest
                            ? '${book.ownerName}님의 친구 신청 수락'
                            : '${book.ownerName}님께 친구 신청'),
                      ),
                    );
                }
              },
            ),
        ],
      ),
    );
  }
}
