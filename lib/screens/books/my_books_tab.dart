import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../services/book_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';
import 'book_detail_sheet.dart';
import 'book_form_screen.dart';

/// 내 책 — 내가 등록한 책 목록 + 등록 버튼
class MyBooksTab extends StatefulWidget {
  final LibraryUser me;
  const MyBooksTab({super.key, required this.me});

  @override
  State<MyBooksTab> createState() => _MyBooksTabState();
}

class _MyBooksTabState extends State<MyBooksTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      BookService.watchMine(widget.me.uid);

  void _openForm() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookFormScreen(me: widget.me),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('내 책')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('책 등록'),
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
          final books =
              BookService.sortNewest(snapshot.data!.docs.map(Book.fromDoc));

          if (books.isEmpty) {
            return PageFrame(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.auto_stories_outlined,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    '아직 등록한 책이 없어요.\n집에 있는 책을 한 권 올려 볼까요?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '책 뒷면 바코드를 찍으면 제목·표지가 자동으로 채워져요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            );
          }

          final available = books.where((b) => b.isAvailable).length;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: books.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('${books.length}권 · 대여 가능 $available권',
                          style: TextStyle(color: theme.colorScheme.outline)),
                    );
                  }
                  final book = books[i - 1];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showBookDetail(context, book, widget.me),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            BookCover(
                                coverUrl: book.coverUrl,
                                title: book.title,
                                width: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (book.author.isNotEmpty)
                                    Text(book.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: theme
                                                .colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      BookStatusChip(status: book.status),
                                      if (book.friendsOnly) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.people_outline,
                                            size: 16,
                                            color: theme.colorScheme.outline),
                                        const SizedBox(width: 2),
                                        Text('친구 공개',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    theme.colorScheme.outline)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
