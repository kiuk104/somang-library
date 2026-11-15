import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/book.dart';
import '../../models/library_user.dart';
import '../../models/wish.dart';
import '../../services/book_lookup_service.dart';
import '../../services/book_service.dart';
import '../../services/photo_barcode.dart';
import '../../services/wish_service.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/page_frame.dart';
import 'cover_picker.dart';

/// 책 등록 / 수정
/// 등록: 바코드 또는 ISBN·제목으로 찾아서 고르면 칸이 채워진다. 못 찾으면 직접 입력.
class BookFormScreen extends StatefulWidget {
  final LibraryUser me;
  final Book? editing; // null 이면 새로 등록

  /// 희망 도서의 "저 있어요"로 들어온 경우 — 칸을 미리 채우고, 저장하면 희망한 사람들에게 알린다
  final Wish? forWish;

  const BookFormScreen({super.key, required this.me, this.editing, this.forWish});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _queryCtrl = TextEditingController();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _publisherCtrl;
  late final TextEditingController _isbnCtrl;
  late final TextEditingController _noteCtrl;
  late String _coverUrl;
  bool _findingCover = false;

  /// 2026-10-24~25 배포판이 확인 없이 넣던 독일 서점 연합 표지 주소 (그림이 없을 수 있다)
  bool get _uncheckedCover => _coverUrl.contains('/opac/mvb/cover');
  late bool _available;
  late bool _friendsOnly;

  List<BookInfo>? _results; // null: 아직 검색 안 함
  bool _searching = false;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.editing;
    final w = widget.forWish;
    _titleCtrl = TextEditingController(text: b?.title ?? w?.title ?? '');
    _authorCtrl = TextEditingController(text: b?.author ?? w?.author ?? '');
    _publisherCtrl =
        TextEditingController(text: b?.publisher ?? w?.publisher ?? '');
    _isbnCtrl = TextEditingController(text: b?.isbn ?? w?.isbn ?? '');
    _noteCtrl = TextEditingController(text: b?.note ?? '');
    _coverUrl = b?.coverUrl ?? w?.coverUrl ?? '';
    _available = b == null || b.status == BookStatus.available;
    _friendsOnly = b?.friendsOnly ?? false;
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _publisherCtrl.dispose();
    _isbnCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 실시간 바코드 스캔 (web/scanner.js) — 찾으면 바로 검색
  Future<void> _scanLive() async {
    if (_searching) return;
    String? isbn;
    try {
      isbn = await PhotoBarcode.scanLive();
    } catch (e) {
      if (mounted) showSnack(context, '스캔을 시작하지 못했어요. ($e)');
      return;
    }
    if (isbn == null || !mounted) return;
    final clean = BookLookupService.findCodeInScan(isbn);
    if (clean == null) return;
    _queryCtrl.text = clean;
    await _search();
  }

  /// 바코드 사진 찍기 — 폰 기본 카메라(자동초점)로 찍고 zxing-wasm 으로 ISBN 을 읽는다
  /// (한국 책의 5자리 부가기호가 같이 찍혀도 978/979 13자리만 골라낸다)
  Future<void> _scan() async {
    if (_searching) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000, // 너무 큰 사진은 줄여서 빠르게
      imageQuality: 90,
    );
    if (photo == null || !mounted) return;

    setState(() => _searching = true);
    String? isbn;
    List<String> values = const [];
    String? error;
    try {
      final bytes = await photo.readAsBytes();
      values = await PhotoBarcode.read(bytes, photo.mimeType ?? 'image/jpeg');
      // ISBN 을 먼저, 없으면 잡지형 책 바코드(419·414·977 + 호수)
      for (final v in values) {
        isbn ??= BookLookupService.findIsbnInScan(v);
      }
      for (final v in values) {
        isbn ??= BookLookupService.findPressCode(v);
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _searching = false);

    if (isbn == null) {
      showSnack(
        context,
        error != null
            ? '사진을 읽지 못했어요. 번호를 직접 입력해 주세요. ($error)'
            : values.isEmpty
                ? '바코드를 못 찾았어요. 바코드가 사진 가운데에 크게, 선명하게 나오게 다시 찍어 주세요.'
                : '읽힌 값(${values.join(', ')})이 책 ISBN 이 아니에요. 978로 시작하는 바코드를 찍어 주세요.',
      );
      return;
    }
    _queryCtrl.text = isbn;
    await _search();
  }

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
    final press = BookLookupService.findPressCode(q);
    // ISBN·잡지 바코드로 딱 한 권이 나오면 바로 채운다
    if (results.length == 1 &&
        (press != null || BookLookupService.cleanIsbn(q) != null)) {
      _pick(results.first);
    } else if (results.isEmpty && press != null) {
      // 잡지형 책: 바깥 데이터베이스에 없다 → 번호만 채우고 직접 입력하게
      _isbnCtrl.text = press;
      showSnack(
          context,
          '잡지용 바코드라 책 정보를 자동으로 못 찾았어요. 제목을 직접 입력해 주세요. '
          '한 번 등록하면 다음부터는 이 바코드로 바로 채워져요.');
    } else if (results.isEmpty && BookLookupService.cleanIsbn(q) != null) {
      // 못 찾았어도 ISBN 은 채워 두기
      _isbnCtrl.text = BookLookupService.cleanIsbn(q)!;
    }
  }

  /// 규칙 길이 제한(제목·저자 200자)에 맞춰 자른다
  static String _cut(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  void _pick(BookInfo info) {
    setState(() {
      _titleCtrl.text = _cut(info.title, 200);
      _authorCtrl.text = _cut(info.author, 200);
      _publisherCtrl.text = _cut(info.publisher, 200);
      // 검색 결과에 ISBN 이 없으면 찍은/입력한 ISBN 을 유지
      if (info.isbn.isNotEmpty) {
        _isbnCtrl.text = info.isbn;
      } else {
        final typed = BookLookupService.findPressCode(_queryCtrl.text) ??
            BookLookupService.cleanIsbn(_queryCtrl.text);
        if (typed != null) _isbnCtrl.text = typed;
      }
      _coverUrl = info.coverUrl;
      _results = null;
    });
    showSnack(context, '책 정보를 채웠어요. 확인 후 저장하세요.');
    if (info.coverUrl.isEmpty) _findCover();
  }

  /// 표지 바꾸기 메뉴 — 사진 찍기·앨범·인터넷에서 찾기·주소 붙여넣기·ISBN·지우기
  Future<void> _changeCover() async {
    final isbn = _isbnCtrl.text.trim();
    final action = await showCoverMenu(
      context,
      hasCover: _coverUrl.isNotEmpty,
      hasIsbn: BookLookupService.cleanIsbn(isbn) != null &&
          !BookLookupService.isPressCode(isbn),
    );
    if (action == null || !mounted) return;
    final title = _titleCtrl.text.trim();
    switch (action) {
      case CoverAction.camera:
      case CoverAction.gallery:
        setState(() => _findingCover = true);
        try {
          final url = await CoverTools.pickAndUpload(
              action == CoverAction.camera
                  ? ImageSource.camera
                  : ImageSource.gallery);
          if (mounted && url != null) {
            setState(() => _coverUrl = url);
            showSnack(context, '표지 사진을 올렸어요. 저장을 눌러야 반영돼요.');
          }
        } catch (e) {
          if (mounted) showSnack(context, '사진을 올리지 못했어요. ($e)');
        }
        if (mounted) setState(() => _findingCover = false);
      case CoverAction.web:
        CoverTools.openImageSearch(title, _authorCtrl.text.trim());
        await _pasteCoverUrl(title);
      case CoverAction.paste:
        await _pasteCoverUrl(title);
      case CoverAction.isbn:
        setState(() => _coverUrl = ''); // 다시 찾으려면 지금 표지를 비운다
        await _findCover(manual: true);
      case CoverAction.clear:
        setState(() => _coverUrl = '');
    }
  }

  Future<void> _pasteCoverUrl(String title) async {
    final url = await showCoverUrlDialog(context, title: title);
    if (url != null && mounted) setState(() => _coverUrl = url);
  }

  /// 검색 결과에 표지가 없으면 표지 서버에서 한 번 더 찾는다 (ISBN 이 있을 때만)
  /// manual: '표지 찾기' 버튼으로 불렀을 때 — 결과를 알려 준다
  Future<void> _findCover({bool manual = false}) async {
    final isbn = _isbnCtrl.text.trim();
    if (BookLookupService.cleanIsbn(isbn) == null ||
        BookLookupService.isPressCode(isbn)) {
      if (manual) showSnack(context, 'ISBN 이 있어야 표지를 찾을 수 있어요.');
      return;
    }
    setState(() => _findingCover = true);
    final cover = await BookLookupService.findCover(isbn);
    if (!mounted) return;
    setState(() => _findingCover = false);
    // 그사이 다른 책을 고르거나 표지가 생겼으면 덮어쓰지 않는다
    if (cover.isEmpty ||
        (_coverUrl.isNotEmpty && !_uncheckedCover) ||
        _isbnCtrl.text.trim() != isbn) {
      if (manual && cover.isEmpty) showSnack(context, '이 책의 표지를 찾지 못했어요.');
      return;
    }
    setState(() => _coverUrl = cover);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showSnack(context, '제목을 입력해 주세요.');
      return;
    }
    setState(() => _saving = true);
    final book = Book(
      id: widget.editing?.id ?? '',
      ownerId: widget.me.uid,
      ownerName: widget.me.name,
      title: title,
      author: _authorCtrl.text.trim(),
      publisher: _publisherCtrl.text.trim(),
      isbn: _isbnCtrl.text.trim(),
      coverUrl: _coverUrl,
      // 규칙은 500 '글자'(코드 포인트) 기준 — 이모지 등 대비해 한 번 더 자른다
      note: String.fromCharCodes(_noteCtrl.text.trim().runes.take(500)),
      status: _available ? BookStatus.available : BookStatus.hidden,
      visibility:
          _friendsOnly ? BookVisibility.friends : BookVisibility.public,
    );
    try {
      var done = _isEdit ? '수정했어요.' : '"$title" 을(를) 등록했어요!';
      if (_isEdit) {
        await BookService.update(book);
      } else {
        final bookId = await BookService.add(book);
        final wish = widget.forWish;
        if (wish != null) {
          // 책은 이미 등록됐다 — 희망 도서 연결이 실패해도 등록은 그대로 둔다
          try {
            await WishService.fulfill(wish.id, bookId);
            done = '"$title" 을(를) 등록했어요! 희망한 분들께 알림을 보냈어요.';
          } catch (e) {
            done = '책은 등록했어요. 다만 희망 도서 연결은 못 했어요. '
                '(${WishService.messageFor(e)})';
          }
        }
      }
      if (!mounted) return;
      // 화면을 닫은 뒤에도 보이도록 ScaffoldMessenger 를 먼저 잡아 둔다
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, '저장하지 못했어요. ($e)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '책 정보 수정' : '책 등록')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.forWish != null) ...[
              // ── 희망 도서에 답하는 중
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.volunteer_activism_outlined,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.forWish!.userName}님'
                        '${widget.forWish!.voters.isEmpty ? '이' : ' 외 ${widget.forWish!.voters.length}명이'}'
                        ' 읽고 싶어 하는 책이에요. 아래 내용을 확인하고 저장하면 알림이 가요.',
                        style: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isEdit) ...[
              // ── 찾기
              FilledButton.icon(
                onPressed: _scanLive,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('바코드 스캔'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('사진으로 찍어서 찾기'),
              ),
              const SizedBox(height: 6),
              Text(
                '스캔이 잘 안 되면 사진으로 찍거나, 아래에 ISBN 숫자를 입력해도 돼요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'ISBN 또는 제목으로 찾기',
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // ── 책 정보
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    // 표지를 누르거나 아래 버튼으로 바꾼다 (사진·인터넷·ISBN)
                    InkWell(
                      onTap: _findingCover ? null : _changeCover,
                      child: Stack(
                        children: [
                          BookCover(
                            coverUrl: _coverUrl,
                            title: _titleCtrl.text.isEmpty
                                ? '표지'
                                : _titleCtrl.text,
                            width: 84,
                          ),
                          if (_findingCover)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color(0x88FFFFFF),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _findingCover ? null : _changeCover,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(84, 32),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(_findingCover ? '표지 처리 중…' : '표지 바꾸기'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        onChanged: (_) => setState(() {}), // 임시 표지 제목 갱신
                        maxLength: 200,
                        decoration: const InputDecoration(
                            labelText: '제목 *', counterText: ''),
                      ),
                      const SizedBox(height: 12),
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
              controller: _publisherCtrl,
              decoration: const InputDecoration(labelText: '출판사'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _isbnCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ISBN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '예: 밑줄 조금 있어요 / 한국어판 / 2권 세트',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('빌려줄 수 있어요'),
              subtitle: Text(_available
                  ? '서가에서 대여 신청을 받을 수 있어요'
                  : '서가에 보이지만 지금은 신청을 받지 않아요'),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('친구에게만 공개'),
              subtitle: Text(_friendsOnly
                  ? '서로 친구인 사람만 이 책을 보고 신청할 수 있어요'
                  : '도서관 사용자 누구나 이 책을 볼 수 있어요'),
              value: _friendsOnly,
              onChanged: (v) => setState(() => _friendsOnly = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(_isEdit ? '저장' : '등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}
