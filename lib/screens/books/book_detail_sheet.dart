import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../services/book_service.dart';
import '../../widgets/book_cover.dart';
import 'book_form_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [book.author, book.publisher]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return SingleChildScrollView(
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
                    BookStatusChip(status: book.status),
                    const SizedBox(height: 12),
                    Text(
                      _mine ? '내 책' : '소장: ${book.ownerName}',
                      style: theme.textTheme.bodyMedium,
                    ),
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
          const SizedBox(height: 24),

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
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                label: Text('삭제',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ] else
              Text('대여가 진행 중이라 지금은 수정할 수 없어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.outline)),
          ] else
            FilledButton.icon(
              onPressed: null, // 다음 단계: 대여 신청 → 소장자 알림
              icon: const Icon(Icons.send_outlined),
              label: Text(book.isAvailable
                  ? '대여 신청 (곧 열려요)'
                  : BookStatus.label(book.status)),
            ),
        ],
      ),
    );
  }
}
