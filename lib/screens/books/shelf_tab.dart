import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/friendship.dart';
import '../../models/library_user.dart';
import '../../services/book_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/book_cover.dart';
import '../help_screen.dart';
import 'book_detail_sheet.dart';

/// 서가 보기 방식 — 격자 3단계(표지 크기) + 한 줄 목록
enum ShelfView {
  small('작게', 96, Icons.grid_view),
  medium('보통', 120, Icons.apps),
  large('크게', 150, Icons.crop_square),
  list('목록', 0, Icons.view_list);

  final String label;
  final double maxExtent; // 격자 한 칸 최대 너비 (목록은 안 씀)
  final IconData icon;
  const ShelfView(this.label, this.maxExtent, this.icon);
}

/// 서가 — 교인들이 등록한 모든 책 (검색 + 대여 가능만 보기)
class ShelfTab extends StatefulWidget {
  final LibraryUser me;
  const ShelfTab({super.key, required this.me});

  @override
  State<ShelfTab> createState() => _ShelfTabState();
}

class _ShelfTabState extends State<ShelfTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      BookService.watchAll();
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyAvailable = false;
  ShelfView _view = ShelfView.small;

  // 내 친구 uid — '친구에게만 공개' 책은 소장자가 나이거나 친구일 때만 보인다
  Set<String> _friendIds = {};
  StreamSubscription<List<Friendship>>? _friendSub;

  @override
  void initState() {
    super.initState();
    _friendSub = FriendService.watchMine(widget.me.uid).listen(
      (list) {
        if (mounted) setState(() => _friendIds = FriendService.friendIds(list));
      },
      onError: (_) {}, // 못 읽으면 친구 없음으로 본다 (친구 공개 책만 숨겨짐)
    );
  }

  bool _canSee(Book b) =>
      !b.friendsOnly ||
      b.ownerId == widget.me.uid ||
      _friendIds.contains(b.ownerId);

  @override
  void dispose() {
    _friendSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('서가'),
        actions: [
          IconButton(
            tooltip: '도움말',
            icon: const Icon(Icons.help_outline),
            onPressed: () => HelpScreen.open(context, widget.me),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = BookService.sortNewest(
              snapshot.data!.docs.map(Book.fromDoc).where(_canSee));
          final q = _query.trim().toLowerCase();
          final books = all.where((b) {
            if (_onlyAvailable && !b.isAvailable) return false;
            if (q.isNotEmpty && !b.searchText.contains(q)) return false;
            return true;
          }).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: '제목·저자·소장자 검색',
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              FilterChip(
                                label: const Text('대여 가능만'),
                                selected: _onlyAvailable,
                                onSelected: (v) =>
                                    setState(() => _onlyAvailable = v),
                              ),
                              const Spacer(),
                              Text('${books.length}권',
                                  style: TextStyle(
                                      color: theme.colorScheme.outline)),
                              const SizedBox(width: 8),
                              PopupMenuButton<ShelfView>(
                                tooltip: '보기 방식',
                                initialValue: _view,
                                onSelected: (v) => setState(() => _view = v),
                                itemBuilder: (_) => [
                                  for (final v in ShelfView.values)
                                    PopupMenuItem(
                                      value: v,
                                      child: Row(
                                        children: [
                                          Icon(v.icon, size: 20),
                                          const SizedBox(width: 10),
                                          Text(v == ShelfView.list
                                              ? '목록'
                                              : '표지 ${v.label}'),
                                        ],
                                      ),
                                    ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_view.icon, size: 20),
                                      const SizedBox(width: 4),
                                      Text(_view.label,
                                          style: const TextStyle(fontSize: 13)),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (books.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          all.isEmpty
                              ? '아직 서가가 비어 있어요.\n"내 책"에서 첫 책을 등록해 주세요!'
                              : '찾는 책이 없어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    )
                  else if (_view == ShelfView.list)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                      sliver: SliverList.separated(
                        itemCount: books.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _ShelfRow(
                          book: books[i],
                          onTap: () =>
                              showBookDetail(context, books[i], widget.me),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: _view.maxExtent, // 작게 96 / 보통 120 / 크게 150
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.46, // 표지(1:1.5) + 제목 2줄 + 소장자
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _ShelfItem(
                            book: books[i],
                            onTap: () =>
                                showBookDetail(context, books[i], widget.me),
                          ),
                          childCount: books.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShelfItem extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _ShelfItem({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // 표지는 남는 높이에 맞춰 줄어든다 (글자 크기를 키워도 넘치지 않게)
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = math.min(box.maxWidth, box.maxHeight / 1.5);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      // 지금 빌릴 수 없는 책은 살짝 흐리게
                      opacity: book.isAvailable ? 1 : 0.45,
                      child: BookCover(
                          coverUrl: book.coverUrl,
                          title: book.title,
                          width: w),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Text(
              book.isAvailable ? book.ownerName : BookStatus.label(book.status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
          ],
        ),
    );
  }
}

/// 목록 보기 — 작은 표지 + 제목 / 저자·소장자 + 상태
class _ShelfRow extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _ShelfRow({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = [
      if (book.author.isNotEmpty) book.author,
      book.ownerName,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Opacity(
              opacity: book.isAvailable ? 1 : 0.45,
              child: BookCover(
                  coverUrl: book.coverUrl, title: book.title, width: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.outline)),
                ],
              ),
            ),
            if (!book.isAvailable) ...[
              const SizedBox(width: 8),
              BookStatusChip(status: book.status),
            ],
          ],
        ),
      ),
    );
  }
}
