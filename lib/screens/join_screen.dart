import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/invite_service.dart';
import '../widgets/page_frame.dart';

/// 로그인은 했지만 users 문서가 없는 사람 (처음 온 교인)
///  - 초대 코드가 있으면: redeemInvite 함수가 계정을 만들고 바로 승인
///  - 없으면: 교인(member)·미승인으로 문서를 만들고 승인 대기
/// 문서가 생기면 AuthGate 가 자동으로 다음 화면으로 넘긴다.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _codeCtrl = TextEditingController(text: InviteService.pendingCode ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    final code = InviteService.normalize(_codeCtrl.text);
    if (name.isEmpty) {
      showSnack(context, '이름을 입력해 주세요.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      if (code.isNotEmpty) {
        await InviteService.redeem(code, name: name);
      } else {
        // 규칙: 스스로 만들 때는 role member + 미승인만 허용
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'id': user.uid,
          'email': user.email ?? '',
          'name': name,
          'role': 'member',
          'talent': 0,
          'imagePath': null,
          'createdAt': FieldValue.serverTimestamp(),
          'library': {'approved': false},
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, InviteService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('처음 오셨군요!')),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '도서관에서 쓸 이름을 알려 주세요.\n책을 빌리고 빌려줄 때 이 이름이 보여요.',
              style: theme.textTheme.bodyLarge,
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('계정: $email',
                  style: TextStyle(color: theme.colorScheme.outline)),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '이름 (실명)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _join(),
              decoration: const InputDecoration(
                labelText: '초대 코드 (있으면)',
                helperText: '초대 코드가 있으면 바로 쓸 수 있고, 없으면 담당자 승인 후 쓸 수 있어요.',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('가입하기'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : AuthService.signOut,
              child: const Text('다른 계정으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
