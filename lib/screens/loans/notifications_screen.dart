import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/friendship.dart';
import '../../models/library_user.dart';
import '../../models/loan.dart';
import '../../services/friend_service.dart';
import '../../services/loan_service.dart';
import '../../widgets/page_frame.dart';

/// 알림함 — 열면 모두 읽음 처리
/// 친구 신청 알림에는 그 자리에서 수락 / 거절 버튼이 붙는다.
class NotificationsScreen extends StatefulWidget {
  final LibraryUser me;
  final List<LibraryNotice> notices;
  const NotificationsScreen(
      {super.key, required this.me, required this.notices});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fmt = DateFormat('M/d HH:mm');
  List<Friendship> _friends = const [];
  StreamSubscription<List<Friendship>>? _sub;
  final Set<String> _busy = {}; // 처리 중인 상대 uid

  @override
  void initState() {
    super.initState();
    // 실패해도 다음에 다시 시도되므로 조용히 넘어간다
    LoanService.markAllRead(widget.notices).catchError((_) {});
    _sub = FriendService.watchMine(widget.me.uid).listen(
      (f) => setState(() => _friends = f),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 이 알림에 해당하는, 아직 답하지 않은 "받은 신청" (없으면 null)
  /// fromId 가 있으면 그것으로, 옛 알림은 본문 앞의 이름으로 찾는다.
  Friendship? _pending(LibraryNotice n) {
    final received = _friends.where((f) => !f.accepted && !f.iRequested);
    if (n.fromId.isNotEmpty) {
      for (final f in received) {
        if (f.otherId == n.fromId) return f;
      }
      return null;
    }
    for (final f in received) {
      if (f.otherName.isNotEmpty && n.body.startsWith('${f.otherName}님')) {
        return f;
      }
    }
    return null;
  }

  Future<void> _answer(Friendship f, bool accept) async {
    if (_busy.contains(f.otherId)) return;
    setState(() => _busy.add(f.otherId));
    try {
      if (accept) {
        await FriendService.accept(f.otherId);
        if (mounted) showSnack(context, '${f.otherName}님과 친구가 되었어요.');
      } else {
        await FriendService.decline(f.otherId);
        if (mounted) showSnack(context, '신청을 거절했어요.');
      }
    } catch (e) {
      if (mounted) showSnack(context, FriendService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy.remove(f.otherId));
    }
  }

  /// 친구 신청 알림의 버튼 줄 (거절 / 수락을 같은 너비로 나란히)
  Widget? _friendActions(LibraryNotice n) {
    if (n.type != 'friend_request') return null;
    final f = _pending(n);
    final theme = Theme.of(context);
    if (f == null) {
      // 이미 처리됐거나(친구/거절/취소) 아직 불러오는 중
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('이미 처리된 신청이에요',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
      );
    }
    if (_busy.contains(f.otherId)) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _answer(f, false),
              child: const Text('거절'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _answer(f, true),
              child: const Text('수락'),
            ),
          ),
        ],
      ),
    );
  }

  /// 버튼이 붙는 알림 한 칸 (ListTile 은 부제목 폭이 좁아 버튼이 잘릴 수 있어 직접 배치)
  Widget _friendTile(LibraryNotice n, Widget actions) {
    final theme = Theme.of(context);
    return Container(
      color: n.read
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(n.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              if (n.createdAt != null)
                Text(_fmt.format(n.createdAt!),
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 4),
          Text(n.body,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          actions,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = widget.notices;
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: list.isEmpty
          ? Center(
              child: Text('아직 알림이 없어요.',
                  style: TextStyle(color: theme.colorScheme.outline)))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    final actions = _friendActions(n);
                    if (actions != null) return _friendTile(n, actions);
                    return ListTile(
                      tileColor: n.read
                          ? null
                          : theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.35),
                      title: Text(n.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(n.body),
                      trailing: n.createdAt == null
                          ? null
                          : Text(_fmt.format(n.createdAt!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.outline)),
                      onTap: () => Navigator.of(context).pop(),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
