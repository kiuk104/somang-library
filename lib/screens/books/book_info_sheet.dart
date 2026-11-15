import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../models/book.dart';
import '../../services/book_lookup_service.dart';
import '../../widgets/book_cover.dart';

/// 책 정보 — 앱 안에서 보는 상세 정보 (출판사·출간일·쪽수·정가·책 소개)
/// 카카오 책 검색 + Google Books 에서 가져온다. 못 찾으면 알라딘 검색 링크를 안내한다.
/// 책 상세 시트 "안에서" 화면만 바뀌어 보이는 내용 부분 (자체 모달 없음)
class BookInfoView extends StatefulWidget {
  final Book book;
  final VoidCallback onBack;
  const BookInfoView({super.key, required this.book, required this.onBack});

  @override
  State<BookInfoView> createState() => _BookInfoViewState();
}

class _BookInfoViewState extends State<BookInfoView> {
  late final Future<BookInfo?> _future = BookLookupService.details(
    isbn: widget.book.isbn,
    title: widget.book.title,
    author: widget.book.author,
  );

  /// 소개 전문 — 카카오가 준 다음 책 페이지, 없으면 다음 검색(ISBN·제목)
  void _openFull(String link) {
    final isbn = widget.book.isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final word = isbn.isNotEmpty
        ? isbn
        : '${widget.book.title} ${widget.book.author}'.trim();
    web.window.open(
        link.isNotEmpty
            ? link
            : 'https://search.daum.net/search?w=bookpage&q=${Uri.encodeQueryComponent(word)}',
        '_blank');
  }

  void _openAladin() {
    final isbn = widget.book.isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final word = isbn.isNotEmpty
        ? isbn
        : '${widget.book.title} ${widget.book.author}'.trim();
    web.window.open(
        'https://www.aladin.co.kr/search/wsearchresult.aspx'
        '?SearchTarget=All&SearchWord=${Uri.encodeQueryComponent(word)}',
        '_blank');
  }

  String _won(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '$b원';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final book = widget.book;

    return FutureBuilder<BookInfo?>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final info = snap.data;

        // 우리 서가에 등록된 값은 그대로 쓰고, 찾아 온 값으로 빈 곳을 채운다
        final title = book.title;
        final author = book.author.isNotEmpty ? book.author : (info?.author ?? '');
        final publisher =
            book.publisher.isNotEmpty ? book.publisher : (info?.publisher ?? '');
        final cover = book.coverUrl.isNotEmpty ? book.coverUrl : (info?.coverUrl ?? '');

        final facts = <(IconData, String)>[
          if (publisher.isNotEmpty) (Icons.apartment_outlined, publisher),
          if ((info?.date ?? '').isNotEmpty)
            (Icons.event_outlined, '출간 ${info!.date}'),
          if ((info?.pages ?? 0) > 0)
            (Icons.menu_book_outlined, '${info!.pages}쪽'),
          if ((info?.price ?? 0) > 0)
            (Icons.sell_outlined, '정가 ${_won(info!.price)}'),
          if (book.isbn.isNotEmpty) (Icons.tag, 'ISBN ${book.isbn}'),
        ];
        final desc = info?.description ?? '';

        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('돌아가기'),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(coverUrl: cover, title: title, width: 96),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (author.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(author,
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final f in facts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(f.$1, size: 18, color: cs.outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f.$2)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (desc.isNotEmpty) ...[
                Text('책 소개',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: cs.primary)),
                const SizedBox(height: 6),
                SelectableText(desc, style: const TextStyle(height: 1.5)),
                if (desc.endsWith('…'))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _openFull(info?.link ?? ''),
                      child: const Text('… 나머지 소개 보기 (다음 책)'),
                    ),
                  ),
              ] else
                Text(
                  info == null
                      ? '이 책의 자세한 정보를 찾지 못했어요.'
                      : '등록된 책 소개가 없어요.',
                  style: TextStyle(color: cs.outline),
                ),
              if (!loading) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _openAladin,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('알라딘에서 더 보기'),
                ),
              ],
            ],
        );
      },
    );
  }
}
