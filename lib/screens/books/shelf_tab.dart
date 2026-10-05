import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../services/book_service.dart';
import '../../widgets/book_cover.dart';
import 'book_detail_sheet.dart';

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
  bool _listView = false; // false: 작은 표지 격자, true: 한 줄 목록

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('서가')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all =
              BookService.sortNewest(snapshot.data!.docs.map(Book.fromDoc));
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
                              SegmentedButton<bool>(
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  padding: WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 4)),
                                ),
                                segments: const [
                                  ButtonSegment(
                                      value: false,
                                      icon: Icon(Icons.grid_view, size: 18),
                                      tooltip: '표지로 보기'),
                                  ButtonSegment(
                                      value: true,
                                      icon: Icon(Icons.view_list, size: 18),
                                      tooltip: '목록으로 보기'),
                                ],
                                selected: {_listView},
                                onSelectionChanged: (v) =>
                                    setState(() => _listView = v.first),
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
                  else if (_listView)
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
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 96, // 폰에서 4열
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
