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
  String? _ownerId; // 고른 소장자 (null: 전체)
  String _ownerName = '';
  ShelfView _view = ShelfView.small;
  bool _showOwner = false; // 격자 보기에서 표지 아래 소장자 이름 표시 (기본 끔)

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
            if (_ownerId != null && b.ownerId != _ownerId) return false;
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
                              Text('${books.length}권',
                                  style: TextStyle(
                                      color: theme.colorScheme.outline)),
                              const Spacer(),
                              PopupMenuButton<Object>(
                                tooltip: '보기 방식',
                                initialValue: _view,
                                onSelected: (v) => setState(() {
                                  if (v is ShelfView) {
                                    _view = v;
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
                          childAspectRatio: _showOwner ? 0.46 : 0.5, // 표지(1:1.5) + 제목 2줄 (+ 소장자)
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _ShelfItem(
                            book: books[i],
                            showOwner: _showOwner,
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
