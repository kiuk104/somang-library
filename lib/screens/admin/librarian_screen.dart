import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/library_user.dart';
import '../../widgets/page_frame.dart';

/// 도서관 담당자 지정·해제 (청소년부 스태프 전용)
/// 규칙: 담당자(library.isLibrarian) 변경은 스태프만 할 수 있다.
/// 담당자는 가입 승인·초대 링크를 쓰고, 새 가입 대기자가 생기면 푸시를 받는다.
class LibrarianScreen extends StatefulWidget {
  final LibraryUser me;
  const LibrarianScreen({super.key, required this.me});

  @override
  State<LibrarianScreen> createState() => _LibrarianScreenState();
}

class _LibrarianScreenState extends State<LibrarianScreen> {
  // 교인(member) 문서만 읽는다 (승인 여부·담당 여부는 클라이언트에서 거른다)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'member')
          .limit(300)
          .snapshots();

  final Set<String> _busy = {}; // 연타 방지

  Future<void> _set(LibraryUser u, bool value) async {
    if (!_busy.add(u.uid)) return;
    setState(() {});
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).update({
        'library.isLibrarian': value,
      });
      if (mounted) {
        showSnack(context,
            value ? '${u.name}님을 담당자로 지정했어요.' : '${u.name}님의 담당자 지정을 풀었어요.');
      }
    } catch (e) {
      if (mounted) showSnack(context, '바꾸지 못했어요. ($e)');
    } finally {
      _busy.remove(u.uid);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('도서관 담당자')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _members,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('오류: ${snapshot.error}');
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // 승인된 교인만 (담당자 먼저, 그다음 이름순)
            final users = snapshot.data!.docs
                .map(LibraryUser.fromDoc)
                .where((u) => u.approved)
                .toList()
              ..sort((a, b) {
                if (a.isLibrarian != b.isLibrarian) {
                  return a.isLibrarian ? -1 : 1;
                }
                return a.name.compareTo(b.name);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    '담당자는 가입 승인·초대 링크를 쓸 수 있고,\n'
                    '새 가입 대기자가 생기면 알림을 받아요.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text('승인된 교인이 아직 없어요.',
                          style: TextStyle(color: theme.colorScheme.outline)),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final u in users)
                          SwitchListTile(
                            title: Text(u.name.isEmpty ? '(이름 없음)' : u.name),
                            subtitle: u.email.isEmpty ? null : Text(u.email),
                            value: u.isLibrarian,
                            onChanged:
                                _busy.contains(u.uid) ? null : (v) => _set(u, v),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
