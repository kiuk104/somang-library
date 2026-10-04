import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/library_user.dart';
import '../../widgets/page_frame.dart';

/// 초대 코드 없이 가입한 교인 승인 (도서관 관리자 전용)
/// 규칙: 스태프 또는 사서만 users.library 를 바꿀 수 있다.
class ApprovalScreen extends StatefulWidget {
  final LibraryUser me;
  const ApprovalScreen({super.key, required this.me});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  // 교인(member) 문서만 — 교인 사서도 읽을 수 있는 쿼리. 승인 여부는 클라이언트에서 거른다.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'member')
          .limit(300)
          .snapshots();

  final Set<String> _approving = {}; // 연타 방지

  Future<void> _approve(String uid, String name) async {
    if (!_approving.add(uid)) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'library.approved': true,
        'library.approvedAt': FieldValue.serverTimestamp(),
        'library.approvedBy': widget.me.uid,
      });
      if (mounted) showSnack(context, '$name님을 승인했어요.');
    } catch (e) {
      if (mounted) showSnack(context, '승인하지 못했어요. ($e)');
    } finally {
      _approving.remove(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('가입 승인')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _members,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('오류: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final waiting = snapshot.data!.docs
                .map(LibraryUser.fromDoc)
                .where((u) => !u.approved)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            if (waiting.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('승인을 기다리는 교인이 없어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.outline)),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final u in waiting)
                    ListTile(
                      title: Text(u.name.isEmpty ? '(이름 없음)' : u.name),
                      subtitle: u.email.isEmpty ? null : Text(u.email),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(72, 40)),
                        onPressed: () => _approve(u.uid, u.name),
                        child: const Text('승인'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
