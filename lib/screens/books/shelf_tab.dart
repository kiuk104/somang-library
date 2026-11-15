import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/friendship.dart';
import '../../models/library_user.dart';
import '../../models/loan.dart';
import '../../services/book_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/book_cover.dart';
import '../help_screen.dart';
import '../loans/notifications_screen.dart';
import '../wishes/wishes_screen.dart';
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
  final List<LibraryNotice> notices; // 알림 종 아이콘용 (HomeShell 이 내려줌)
  const ShelfTab({super.key, required this.me, this.notices = const []});

  @override
  State<ShelfTab> createState() => _ShelfTabState();
}

class _ShelfTabState extends State<ShelfTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      BookService.watchAll();
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyAvailable = false;
  bool _onlyFriends = false; // 친구가 소장한 책만
  bool _onlyGiveaway = false; // 소장자가 기증하려고 내놓은 책만
  String? _ownerId; // 고른 소장자 (null: 전체)
  String _ownerName = '';
  ShelfView _view = ShelfView.small;
  bool _showOwner = false; // 격자 보기에서 표지 아래 소장자 이름 표시 (기본 끔)
  bool _groupSeries = true; // 같은 시리즈(제목 끝 권 번호)를 한 칸으로 묶기

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

  /// 소장자 고르기 (책이 있는 사람만, 이름 검색 가능)
  Future<void> _pickOwner(List<_OwnerEntry> owners) async {
    final picked = await showModalBottomSheet<_OwnerEntry?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _OwnerPicker(owners: owners, selectedId: _ownerId),
    );
    // 닫기만 하면 null, '전체 소장자'는 빈 id 로 돌아온다
    if (picked == null) return;
    setState(() {
      _ownerId = picked.id.isEmpty ? null : picked.id;
      _ownerName = picked.name;
    });
  }

  /// 시리즈 화면 — 권 순서대로 (서가 필터와 상관없이 그 시리즈 전체)
  void _openSeries(_SeriesGroup group) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SeriesScreen(
        me: widget.me,
        seriesKey: group.key,
        name: group.name,
        canSee: _canSee,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('서가'),
        actions: [
          IconButton(
            tooltip: '알림',
            icon: Badge(
              isLabelVisible: widget.notices.any((n) => !n.read),
              label: Text('${widget.notices.where((n) => !n.read).length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  NotificationsScreen(me: widget.me, notices: widget.notices),
            )),
          ),
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
          // 소장자 고르기 목록 — 지금 볼 수 있는 책의 소장자 (책 많은 순)
          final ownerMap = <String, _OwnerEntry>{};
          for (final b in all) {
            final e = ownerMap.putIfAbsent(
                b.ownerId, () => _OwnerEntry(b.ownerId, b.ownerName));
            e.count++;
          }
          final owners = ownerMap.values.toList()
            ..sort((a, b) => b.count != a.count
                ? b.count.compareTo(a.count)
                : a.name.compareTo(b.name));

          final books = all.where((b) {
            if (_onlyAvailable && !b.isAvailable) return false;
            if (_onlyFriends && !_friendIds.contains(b.ownerId)) return false;
            if (_onlyGiveaway && !b.giveaway) return false;
            if (_ownerId != null && b.ownerId != _ownerId) return false;
            if (q.isNotEmpty && !b.searchText.contains(q)) return false;
            return true;
          }).toList();
          // 화면에 놓을 칸: Book 또는 _SeriesGroup (시리즈 묶기)
          final items = _groupSeries ? _SeriesGroup.group(books) : books;
          final seriesCount = items.whereType<_SeriesGroup>().length;

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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              FilterChip(
                                label: const Text('대여 가능만'),
                                selected: _onlyAvailable,
                                onSelected: (v) =>
                                    setState(() => _onlyAvailable = v),
                              ),
                              FilterChip(
                                avatar: const Icon(Icons.people_outline, size: 18),
                                label: const Text('친구 책만'),
                                selected: _onlyFriends,
                                onSelected: (v) =>
                                    setState(() => _onlyFriends = v),
                              ),
                              FilterChip(
                                avatar: const Icon(Icons.card_giftcard_outlined,
                                    size: 18),
                                label: const Text('기증 책만'),
                                selected: _onlyGiveaway,
                                onSelected: (v) =>
                                    setState(() => _onlyGiveaway = v),
                              ),
                              if (_ownerId == null)
                                ActionChip(
                                  avatar: const Icon(Icons.person_outline,
                                      size: 18),
                                  label: const Text('소장자'),
                                  onPressed: () => _pickOwner(owners),
                                )
                              else
                                InputChip(
                                  avatar: const Icon(Icons.person, size: 18),
                                  label: Text(_ownerName),
                                  onPressed: () => _pickOwner(owners),
                                  onDeleted: () =>
                                      setState(() => _ownerId = null),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                  seriesCount == 0
                                      ? '${books.length}권'
                                      : '${books.length}권 · 시리즈 $seriesCount개',
                                  style: TextStyle(
                                      color: theme.colorScheme.outline)),
                              const Spacer(),
                              // 서가에 없는 책 → 희망 도서
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () =>
                                    WishesScreen.open(context, widget.me),
                                icon: const Icon(Icons.bookmark_add_outlined,
                                    size: 18),
                                label: const Text('희망 도서'),
                              ),
                              PopupMenuButton<Object>(
                                tooltip: '보기 방식',
                                initialValue: _view,
                                onSelected: (v) => setState(() {
                                  if (v is ShelfView) {
                                    _view = v;
                                  } else if (v == 'series') {
                                    _groupSeries = !_groupSeries; // 시리즈 묶기 켜기/끄기
                                  } else {
                                    _showOwner = !_showOwner; // 소장자 표시 켜기/끄기
                                  }
                                }),
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
                                  const PopupMenuDivider(),
                                  CheckedPopupMenuItem<Object>(
                                    value: 'series',
                                    checked: _groupSeries,
                                    child: const Text('시리즈 묶어 보기'),
                                  ),
                                  CheckedPopupMenuItem<Object>(
                                    value: 'owner',
                                    checked: _showOwner,
                                    child: const Text('소장자 이름 표시'),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              all.isEmpty
                                  ? '아직 서가가 비어 있어요.\n"내 책"에서 첫 책을 등록해 주세요!'
                                  : '찾는 책이 없어요.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: theme.colorScheme.outline),
                            ),
                            if (all.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              // 검색어를 들고 희망 도서 올리기로
                              FilledButton.tonalIcon(
                                onPressed: () => WishesScreen.open(
                                    context, widget.me,
                                    query: _query.trim()),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                label: const Text('희망 도서로 올리기'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '읽고 싶은 책을 올려 두면\n그 책을 가진 분이 등록해 줄 수 있어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else if (_view == ShelfView.list)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return item is _SeriesGroup
                              ? _SeriesRow(
                                  group: item,
                                  onTap: () => _openSeries(item),
                                )
                              : _ShelfRow(
                                  book: item as Book,
                                  onTap: () => showBookDetail(
                                      context, item as Book, widget.me),
                                );
                        },
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
                          childAspectRatio: _showOwner ? 0.46 : 0.5, // 표지(1:1.5) + 제목 2줄 (+ 소장자)
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final item = items[i];
                            return item is _SeriesGroup
                                ? _SeriesItem(
                                    group: item,
                                    showOwner: _showOwner,
                                    onTap: () => _openSeries(item),
                                  )
                                : _ShelfItem(
                                    book: item as Book,
                                    showOwner: _showOwner,
                                    onTap: () => showBookDetail(
                                        context, item as Book, widget.me),
                                  );
                          },
                          childCount: items.length,
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
  final bool showOwner;
  final VoidCallback onTap;
  const _ShelfItem(
      {required this.book, required this.onTap, this.showOwner = false});

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
                    child: SizedBox(
                      width: w,
                      height: w * 1.5,
                      child: Stack(
                        children: [
                          Opacity(
                            // 지금 빌릴 수 없는 책은 흐리게 (배지는 또렷하게 따로 올린다)
                            opacity: book.isAvailable ? 1 : 0.5,
                            child: BookCover(
                                coverUrl: book.coverUrl,
                                title: book.title,
                                width: w),
                          ),
                          if (!book.isAvailable)
                            Positioned(
                              left: 4,
                              top: 4,
                              child: BookStatusBadge(status: book.status),
                            ),
                          if (book.giveaway)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(Icons.card_giftcard,
                                    size: 12,
                                    color: theme.colorScheme.onPrimary),
                              ),
                            ),
                        ],
                      ),
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
            if (showOwner)
              Text(
                book.ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11, color: theme.colorScheme.outline),
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

/// 시리즈 한 묶음 — 같은 seriesKey 를 가진 책 2권 이상 (여러 소장자 섞여도 된다)
class _SeriesGroup {
  final String key;
  final String name;
  final List<Book> books; // 권 번호 순

  _SeriesGroup(this.key, this.name, this.books);

  int get availableCount => books.where((b) => b.isAvailable).length;

  /// 소장자 이름 (중복 없이)
  List<String> get ownerNames => {for (final b in books) b.ownerName}.toList();

  /// '1–5권' / '1·2·4권'
  String get volumeLabel {
    final v = {for (final b in books) b.volume}.toList()..sort();
    final contiguous = v.last - v.first == v.length - 1;
    return contiguous && v.length > 2
        ? '${v.first}–${v.last}권'
        : '${v.join('·')}권';
  }

  /// 시리즈 권 번호 순, 같은 권은 소장자 이름 순
  static List<Book> sortVolumes(Iterable<Book> books) => books.toList()
    ..sort((a, b) => a.volume != b.volume
        ? a.volume.compareTo(b.volume)
        : a.ownerName.compareTo(b.ownerName));

  /// 책 목록(이미 정렬됨)을 칸 목록으로 — 2권 이상인 시리즈는 그중 첫 책 자리에 한 칸으로
  static List<Object> group(List<Book> books) {
    final byKey = <String, List<Book>>{};
    for (final b in books) {
      final k = b.seriesKey;
      if (k != null) byKey.putIfAbsent(k, () => []).add(b);
    }
    final out = <Object>[];
    final done = <String>{};
    for (final b in books) {
      final k = b.seriesKey;
      final list = k == null ? null : byKey[k];
      if (list == null || list.length < 2) {
        out.add(b);
      } else if (done.add(k!)) {
        final sorted = sortVolumes(list);
        out.add(_SeriesGroup(k, sorted.first.seriesName!, sorted));
      }
    }
    return out;
  }
}

/// 격자 보기의 시리즈 칸 — 표지 3장을 겹쳐 쌓고 권 수 배지
class _SeriesItem extends StatelessWidget {
  final _SeriesGroup group;
  final bool showOwner;
  final VoidCallback onTap;
  const _SeriesItem(
      {required this.group, required this.onTap, this.showOwner = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owners = group.ownerNames;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final w = math.min(box.maxWidth, box.maxHeight / 1.5);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: w,
                    height: w * 1.5,
                    child: Opacity(
                      // 빌릴 수 있는 권이 하나도 없으면 흐리게
                      opacity: group.availableCount > 0 ? 1 : 0.5,
                      child: _SeriesStack(group: group, width: w),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          if (showOwner)
            Text(
              owners.length == 1 ? owners.first : '소장자 ${owners.length}명',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

/// 표지 겹쳐 쌓기 (뒤 2장은 다음 권 표지, 앞에 첫 권) + 오른쪽 아래 'N권' 배지
class _SeriesStack extends StatelessWidget {
  final _SeriesGroup group;
  final double width;
  const _SeriesStack({required this.group, required this.width});

  @override
  Widget build(BuildContext context) {
    final cw = width * 0.84; // 앞 표지 너비
    final step = (width - cw) / 2; // 한 장씩 밀리는 간격
    final books = group.books;
    Book at(int i) => books[i < books.length ? i : books.length - 1];
    Widget layer(Book b, int depth) => Positioned(
          left: step * depth,
          bottom: step * depth,
          child: Opacity(
            opacity: depth == 0 ? 1 : (depth == 1 ? 0.75 : 0.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cw * 0.06),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(1, 1)),
                ],
              ),
              child: BookCover(coverUrl: b.coverUrl, title: b.title, width: cw),
            ),
          ),
        );
    return Stack(
      children: [
        // 뒤에서부터 그린다 (Positioned 의 bottom 기준이라 위로·오른쪽으로 밀린다)
        if (books.length > 2) layer(at(2), 2),
        layer(at(1), 1),
        layer(at(0), 0),
        Positioned(
          left: cw - 4,
          bottom: 4,
          child: FractionalTranslation(
            translation: const Offset(-1, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xDD000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${books.length}권',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 목록 보기의 시리즈 줄
class _SeriesRow extends StatelessWidget {
  final _SeriesGroup group;
  final VoidCallback onTap;
  const _SeriesRow({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owners = group.ownerNames;
    final sub = [
      group.volumeLabel,
      '대여 가능 ${group.availableCount}권',
      owners.length == 1 ? owners.first : '소장자 ${owners.length}명',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 60,
              child: _SeriesStack(group: group, width: 40),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
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
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// 시리즈 화면 — 그 시리즈의 모든 권 (권 순서). 대여 상태가 바뀌면 바로 반영되게 직접 구독
class _SeriesScreen extends StatefulWidget {
  final LibraryUser me;
  final String seriesKey;
  final String name;
  final bool Function(Book) canSee;
  const _SeriesScreen({
    required this.me,
    required this.seriesKey,
    required this.name,
    required this.canSee,
  });

  @override
  State<_SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<_SeriesScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      BookService.watchAll();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = _SeriesGroup.sortVolumes(snapshot.data!.docs
              .map(Book.fromDoc)
              .where((b) => widget.canSee(b) && b.seriesKey == widget.seriesKey));
          if (books.isEmpty) {
            return Center(
                child: Text('이 시리즈의 책이 없어요.',
                    style: TextStyle(color: theme.colorScheme.outline)));
          }
          final group = _SeriesGroup(widget.seriesKey, widget.name, books);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
                itemCount: books.length + 1,
                separatorBuilder: (_, i) =>
                    i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        '${group.volumeLabel} · 대여 가능 ${group.availableCount}권'
                        ' · 소장자 ${group.ownerNames.join(', ')}',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    );
                  }
                  final b = books[i - 1];
                  return _ShelfRow(
                    book: b,
                    onTap: () => showBookDetail(context, b, widget.me),
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

/// 소장자 한 명 (책 수 포함)
class _OwnerEntry {
  final String id;
  final String name;
  int count = 0;
  _OwnerEntry(this.id, this.name);
}

/// 소장자 고르기 시트 — 이름으로 거르고 눌러서 고른다
class _OwnerPicker extends StatefulWidget {
  final List<_OwnerEntry> owners;
  final String? selectedId;
  const _OwnerPicker({required this.owners, required this.selectedId});

  @override
  State<_OwnerPicker> createState() => _OwnerPickerState();
}

class _OwnerPickerState extends State<_OwnerPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final list = widget.owners
        .where((o) => q.isEmpty || o.name.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: '소장자 이름 검색',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('전체 소장자'),
            trailing: widget.selectedId == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, _OwnerEntry('', '')),
          ),
          const Divider(height: 1),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('찾는 소장자가 없어요.',
                        style: TextStyle(color: theme.colorScheme.outline)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final o = list[i];
                      return ListTile(
                        title: Text(o.name.isEmpty ? '(이름 없음)' : o.name),
                        subtitle: Text('${o.count}권'),
                        trailing: o.id == widget.selectedId
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, o),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
