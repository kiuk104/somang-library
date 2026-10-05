import 'package:flutter/material.dart';

import '../../models/friendship.dart';
import '../../models/library_user.dart';
import '../../services/friend_service.dart';
import '../../widgets/page_frame.dart';

/// 친구 — 이름으로 찾아 신청, 받은 신청 수락, 내 친구 목록
/// 친구에게만 공개한 책은 서로 친구인 사람에게만 보이고 신청할 수 있다.
class FriendsScreen extends StatefulWidget {
  final LibraryUser me;
  const FriendsScreen({super.key, required this.me});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final Stream<List<Friendship>> _stream =
      FriendService.watchMine(widget.me.uid);
  final _searchCtrl = TextEditingController();
  List<FriendCandidate>? _results; // null: 아직 검색 안 함
  bool _searching = false;
  final Set<String> _busy = {}; // 연타 방지 (상대 uid)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.runes.length < 2) {
      showSnack(context, '이름을 두 글자 이상 입력해 주세요.');
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await FriendService.search(q);
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) showSnack(context, FriendService.messageFor(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _do(String uid, Future<Object?> Function() run, String done) async {
    if (!_busy.add(uid)) return;
    setState(() {});
    try {
      final r = await run();
      if (mounted) {
        showSnack(context, r == 'accepted' ? '서로 친구가 되었어요!' : done);
      }
    } catch (e) {
      if (mounted) showSnack(context, FriendService.messageFor(e));
    } finally {
      _busy.remove(uid);
      if (mounted) setState(() {});
    }
  }

  Future<void> _remove(Friendship f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구를 끊을까요?'),
        content: Text('${f.otherName}님과 친구가 아니게 돼요.\n'
            '서로 친구에게만 공개한 책도 더는 보이지 않아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('끊기')),
        ],
      ),
    );
    if (ok != true) return;
    await _do(f.otherId, () => FriendService.remove(f.otherId), '친구를 끊었어요.');
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('친구')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: StreamBuilder<List<Friendship>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('오류: ${snapshot.error}');
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snapshot.data!;
            int byName(Friendship a, Friendship b) =>
                a.otherName.compareTo(b.otherName);
            final received = all
                .where((f) => !f.accepted && !f.iRequested)
                .toList()
              ..sort(byName);
            final sent =
                all.where((f) => !f.accepted && f.iRequested).toList()
                  ..sort(byName);
            final friends = all.where((f) => f.accepted).toList()
              ..sort(byName);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 이름으로 찾기
                _sectionTitle('이름으로 찾기'),
                TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '친구의 이름',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5)),
                          )
                        : IconButton(
                            tooltip: '찾기',
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _search,
                          ),
                  ),
                ),
                if (_results != null) ...[
                  const SizedBox(height: 8),
                  if (_results!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('찾는 사람이 없어요. 이름을 다시 확인해 주세요.',
                          style: TextStyle(color: theme.colorScheme.outline)),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final c in _results!)
                            _candidateTile(c, FriendService.relationTo(all, c.uid)),
                        ],
                      ),
                    ),
                ],

                // ── 받은 신청
                if (received.isNotEmpty) ...[
                  _sectionTitle('받은 친구 신청 (${received.length})'),
                  Card(
                    child: Column(
                      children: [
                        for (final f in received)
                          ListTile(
                            title: Text(f.otherName),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _busy.contains(f.otherId)
                                      ? null
                                      : () => _do(
                                          f.otherId,
                                          () => FriendService.decline(f.otherId),
                                          '거절했어요.'),
                                  child: const Text('거절'),
                                ),
                                FilledButton.tonal(
                                  onPressed: _busy.contains(f.otherId)
                                      ? null
                                      : () => _do(
                                          f.otherId,
                                          () async {
                                            await FriendService.accept(f.otherId);
                                            return 'accepted';
                                          },
                                          ''),
                                  child: const Text('수락'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // ── 내 친구
                _sectionTitle('내 친구 (${friends.length})'),
                if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                        '아직 친구가 없어요.\n위에서 이름으로 찾거나, 서가의 책 상세에서 소장자에게 친구 신청을 해 보세요.',
                        style: TextStyle(color: theme.colorScheme.outline)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final f in friends)
                          ListTile(
                            leading: const Icon(Icons.people_outline),
                            title: Text(f.otherName),
                            trailing: IconButton(
                              tooltip: '친구 끊기',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: _busy.contains(f.otherId)
                                  ? null
                                  : () => _remove(f),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ── 보낸 신청
                if (sent.isNotEmpty) ...[
                  _sectionTitle('보낸 친구 신청 (${sent.length})'),
                  Card(
                    child: Column(
                      children: [
                        for (final f in sent)
                          ListTile(
                            title: Text(f.otherName),
                            subtitle: const Text('수락을 기다리고 있어요'),
                            trailing: TextButton(
                              onPressed: _busy.contains(f.otherId)
                                  ? null
                                  : () => _do(
                                      f.otherId,
                                      () => FriendService.cancel(f.otherId),
                                      '신청을 취소했어요.'),
                              child: const Text('취소'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _candidateTile(FriendCandidate c, FriendRelation rel) {
    final busy = _busy.contains(c.uid);
    final Widget action;
    switch (rel) {
      case FriendRelation.friend:
        action = const Text('친구');
      case FriendRelation.sentRequest:
        action = const Text('신청함');
      case FriendRelation.receivedRequest:
        action = FilledButton.tonal(
          onPressed: busy
              ? null
              : () => _do(c.uid, () async {
                    await FriendService.accept(c.uid);
                    return 'accepted';
                  }, ''),
          child: const Text('수락'),
        );
      case FriendRelation.none:
        action = FilledButton.tonal(
          onPressed: busy
              ? null
              : () => _do(c.uid, () => FriendService.request(c.uid),
                  '${c.name}님께 친구 신청을 보냈어요.'),
          child: const Text('친구 신청'),
        );
    }
    return ListTile(
      title: Text(c.name),
      subtitle: c.hint.isEmpty ? null : Text(c.hint),
      trailing: action,
    );
  }
}
