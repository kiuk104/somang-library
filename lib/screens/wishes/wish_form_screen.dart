import 'package:flutter/material.dart';

import '../../services/book_lookup_service.dart';
import '../../services/wish_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';

/// 희망 도서 올리기 — 책을 찾아서 고르거나 제목을 직접 입력한다
/// 저장되면 true 로 닫힌다.
class WishFormScreen extends StatefulWidget {
  /// 서가에서 검색하다 넘어온 경우의 검색어
  final String initialQuery;
  const WishFormScreen({super.key, this.initialQuery = ''});

  @override
  State<WishFormScreen> createState() => _WishFormScreenState();
}

class _WishFormScreenState extends State<WishFormScreen> {
  late final TextEditingController _queryCtrl;
  late final TextEditingController _titleCtrl;
  final _authorCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  // 검색 결과에서 고른 책의 나머지 정보 (화면에는 표지만 보인다)
  String _publisher = '';
  String _isbn = '';
  String _coverUrl = '';

  List<BookInfo>? _results; // null: 아직 검색 안 함
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery.trim();
    _queryCtrl = TextEditingController(text: q);
    // ISBN 이 아니면 제목 칸에도 미리 넣어 둔다
    _titleCtrl = TextEditingController(
        text: BookLookupService.cleanIsbn(q) == null ? q : '');
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  static String _cut(String s, int max) =>
      String.fromCharCodes(s.runes.take(max));

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    final results = await BookLookupService.search(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
    });
  }

  void _pick(BookInfo info) {
    setState(() {
      _titleCtrl.text = _cut(info.title, 200);
      _authorCtrl.text = _cut(info.author, 200);
      _publisher = _cut(info.publisher, 200);
      _isbn = info.isbn;
      _coverUrl = info.coverUrl;
      _results = null;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showSnack(context, '책 제목을 입력해 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      final status = await WishService.create(
        title: title,
        author: _authorCtrl.text.trim(),
        publisher: _publisher,
        isbn: _isbn,
        coverUrl: _coverUrl,
        note: _cut(_noteCtrl.text.trim(), 200),
      );
      if (!mounted) return;
      // 화면을 닫은 뒤에도 보이도록 ScaffoldMessenger 를 먼저 잡아 둔다
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
          content: Text(status == 'voted'
              ? '같은 책의 희망이 이미 있어서 "저도 읽고 싶어요"를 눌러 두었어요.'
              : '"$title" 을(를) 희망 도서로 올렸어요!')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, WishService.messageFor(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('희망 도서 올리기')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '서가에 없는 책을 올려 두면, 그 책을 가진 분이 보고 등록해 줄 수 있어요. '
              '책이 들어오면 알림이 가요.',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            // ── 찾기
            TextField(
              controller: _queryCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: '제목 또는 ISBN 으로 찾기',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search,
                      ),
              ),
            ),
            if (_results != null) ...[
              const SizedBox(height: 12),
              if (_results!.isEmpty)
                Text(
                  '찾지 못했어요. 아래에 직접 입력해 주세요.',
                  style: TextStyle(color: theme.colorScheme.outline),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final info in _results!)
                        ListTile(
                          leading: BookCover(
                              coverUrl: info.coverUrl,
                              title: info.title,
                              width: 36),
                          title: Text(info.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            [info.author, info.publisher, info.year]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _pick(info),
                        ),
                    ],
                  ),
                ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            // ── 내용
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListenableBuilder(
                  listenable: _titleCtrl,
                  builder: (context, _) => BookCover(
                    coverUrl: _coverUrl,
                    title: _titleCtrl.text.trim().isEmpty
                        ? '?'
                        : _titleCtrl.text.trim(),
                    width: 72,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        maxLength: 200,
                        decoration: const InputDecoration(
                            labelText: '제목 *', counterText: ''),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _authorCtrl,
                        maxLength: 200,
                        decoration: const InputDecoration(
                            labelText: '저자', counterText: ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '한마디 (선택)',
                hintText: '예: 한국어판이면 좋겠어요 / 아이와 같이 읽고 싶어요',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: const Text('희망 도서로 올리기'),
            ),
          ],
        ),
      ),
    );
  }
}
