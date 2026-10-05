import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/library_user.dart';
import '../../services/account_service.dart';
import '../../widgets/page_frame.dart';
import '../../widgets/rename_dialog.dart';

/// 교인 목록 — 이름 수정 (도서관 관리자 전용)
/// 교인(role member) 계정만 보인다. 청소년부 이름은 겨자씨 앱에서 관리한다.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _members =
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'member')
          .limit(300)
          .snapshots();

  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _busy = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _rename(LibraryUser u) async {
    final name = await showRenameDialog(context,
        current: u.name, title: '${u.name.isEmpty ? '교인' : u.name}님 이름 수정');
    if (name == null || !mounted || !_busy.add(u.uid)) return;
    setState(() {});
    try {
      await AccountService.rename(name, uid: u.uid);
      if (mounted) showSnack(context, '이름을 "$name"(으)로 바꿨어요.');
    } catch (e) {
      if (mounted) showSnack(context, AccountService.messageFor(e));
    } finally {
      _busy.remove(u.uid);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('교인 이름 수정')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _members,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('오류: ${snapshot.error}');
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final q = _query.trim().toLowerCase();
            final users = snapshot.data!.docs
                .map(LibraryUser.fromDoc)
                .where((u) =>
                    q.isEmpty ||
                    u.name.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '이름·이메일 검색',
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text('${users.length}명 · 눌러서 이름을 고쳐요',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ),
                if (users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text('찾는 교인이 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final u in users)
                          ListTile(
                            title: Text(u.name.isEmpty ? '(이름 없음)' : u.name),
                            subtitle: Text([
                              if (!u.approved) '승인 대기',
                              if (u.isLibrarian) '도서관 담당',
                              if (u.email.isNotEmpty) u.email,
                            ].join(' · ')),
                            trailing: _busy.contains(u.uid)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5))
                                : const Icon(Icons.edit_outlined),
                            onTap:
                                _busy.contains(u.uid) ? null : () => _rename(u),
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
