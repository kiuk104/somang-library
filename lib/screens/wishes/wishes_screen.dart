import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../models/wish.dart';
import '../../services/wish_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';
import '../books/book_detail_sheet.dart';
import '../books/book_form_screen.dart';
import 'wish_form_screen.dart';

/// 희망 도서 — 서가에 없는 책을 "읽고 싶어요"로 올려 두는 목록
/// 다른 사람은 "저도 읽고 싶어요"(공감) 또는 "저 있어요"(책 등록)로 답한다.
class WishesScreen extends StatefulWidget {
  final LibraryUser me;

  /// 서가에서 검색하다 넘어온 검색어 — 있으면 바로 올리기 화면을 연다
  final String startQuery;

  const WishesScreen({super.key, required this.me, this.startQuery = ''});

  static Future<void> open(BuildContext context, LibraryUser me,
          {String query = ''}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WishesScreen(me: me, startQuery: query),
      ));

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

class _WishesScreenState extends State<WishesScreen> {
  late final Stream<List<Wish>> _stream = WishService.watchAll();
  final Set<String> _busy = {}; // 처리 중인 희망 도서 ID

  @override
  void initState() {
    super.initState();
    if (widget.startQuery.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _add(query: widget.startQuery);
      });
    }
  }

  Future<void> _add({String query = ''}) => Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => WishFormScreen(initialQuery: query),
        ),
      );

  /// 버튼 하나를 처리하는 동안 그 카드의 버튼을 잠근다
  Future<void> _run(String wishId, Future<void> Function() job) async {
    if (_busy.contains(wishId)) return;
    setState(() => _busy.add(wishId));
    try {
      await job();
    } catch (e) {
      if (mounted) showSnack(context, WishService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy.remove(wishId));
    }
  }

  Future<void> _delete(Wish w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('희망 도서 지우기'),
        content: Text('"${w.title}" 을(를) 희망 도서에서 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(w.id, () => WishService.delete(w.id));
  }

  /// "저 있어요" → 책 등록 화면 (칸이 미리 채워져 있고, 저장하면 알림이 간다)
  void _haveIt(Wish w) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookFormScreen(me: widget.me, forWish: w),
    ));
  }

  /// 들어온 책 → 책 상세 (대여 신청은 거기서)
  Future<void> _openBook(Wish w) => _run(w.id, () async {
        final doc = await FirebaseFirestore.instance
            .collection('books')
            .doc(w.bookId)
            .get();
        if (!mounted) return;
        if (!doc.exists) {
          showSnack(context, '지금은 서가에 없는 책이에요.');
          return;
        }
        await showBookDetail(context, Book.fromDoc(doc), widget.me);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('희망 도서')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('희망 도서 올리기'),
      ),
      body: StreamBuilder<List<Wish>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final open = WishService.openSorted(snapshot.data!);
          final done = WishService.recentFulfilled(snapshot.data!);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Text(
                    '서가에 없는 책 중에 읽고 싶은 책을 올려 주세요. '
                    '이 중에 갖고 계신 책이 있다면 "저 있어요"를 눌러 등록해 주세요!',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  if (open.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        '아직 올라온 희망 도서가 없어요.\n읽고 싶은 책을 처음으로 올려 보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                  for (final w in open)
                    _WishCard(
                      wish: w,
                      me: widget.me,
                      busy: _busy.contains(w.id),
                      onVote: () => _run(
                          w.id,
                          () => WishService.vote(
                              w.id, !w.votedBy(widget.me.uid))),
                      onHaveIt: () => _haveIt(w),
                      onDelete: () => _delete(w),
                    ),
                  if (done.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                      child: Text('최근에 들어온 책',
                          style: theme.textTheme.titleSmall),
                    ),
                    for (final w in done)
                      _WishCard(
                        wish: w,
                        me: widget.me,
                        busy: _busy.contains(w.id),
                        onOpenBook: () => _openBook(w),
                        onDelete: () => _delete(w),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  final Wish wish;
  final LibraryUser me;
  final bool busy;
  final VoidCallback? onVote;
  final VoidCallback? onHaveIt;
  final VoidCallback? onOpenBook;
  final VoidCallback onDelete;

  const _WishCard({
    required this.wish,
    required this.me,
    required this.busy,
    required this.onDelete,
    this.onVote,
    this.onHaveIt,
    this.onOpenBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = TextStyle(fontSize: 13, color: theme.colorScheme.outline);
    final mine = wish.userId == me.uid;
    final voted = wish.votedBy(me.uid);
    final canDelete = mine || me.isLibraryAdmin;

    final who = wish.isOpen
        ? (wish.voters.isEmpty
            ? '${wish.userName}님이 읽고 싶어 해요'
            : '${wish.userName}님 외 ${wish.voters.length}명이 읽고 싶어 해요')
        : '${wish.fulfilledByName}님이 등록했어요';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(
                    coverUrl: wish.coverUrl, title: wish.title, width: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wish.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                      if (wish.author.isNotEmpty)
                        Text(wish.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: outline),
                      const SizedBox(height: 4),
                      Text(who, style: outline),
                      if (wish.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('"${wish.note}"',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: '지우기',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close,
                        size: 18, color: theme.colorScheme.outline),
                    onPressed: busy ? null : onDelete,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: wish.isOpen
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (mine)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text('내가 올린 희망 도서', style: outline),
                          )
                        else ...[
                          TextButton.icon(
                            onPressed: busy ? null : onVote,
                            icon: Icon(
                                voted ? Icons.favorite : Icons.favorite_border,
                                size: 18),
                            label: Text(voted ? '읽고 싶어요 취소' : '저도 읽고 싶어요'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: busy ? null : onHaveIt,
                            icon: const Icon(Icons.volunteer_activism_outlined,
                                size: 18),
                            label: const Text('저 있어요'),
                          ),
                        ],
                      ],
                    ))
                  : Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: busy ? null : onOpenBook,
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: const Text('책 보기'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
