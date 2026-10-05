import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/loan.dart';
import '../../services/loan_service.dart';

/// 알림함 — 열면 모두 읽음 처리
class NotificationsScreen extends StatefulWidget {
  final List<LibraryNotice> notices;
  const NotificationsScreen({super.key, required this.notices});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _fmt = DateFormat('M/d HH:mm');

  @override
  void initState() {
    super.initState();
    // 실패해도 다음에 다시 시도되므로 조용히 넘어간다
    LoanService.markAllRead(widget.notices).catchError((_) {});
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
