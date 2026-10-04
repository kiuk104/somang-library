import 'package:flutter/material.dart';

import '../models/library_user.dart';
import '../services/auth_service.dart';
import '../services/invite_service.dart';
import '../widgets/page_frame.dart';

/// 교인(member) 이지만 아직 승인 전
/// 담당자가 승인하거나, 초대 코드를 넣으면 users 문서가 바뀌어 AuthGate 가 자동으로 넘긴다.
class PendingScreen extends StatefulWidget {
  final LibraryUser me;
  const PendingScreen({super.key, required this.me});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  late final TextEditingController _codeCtrl =
      TextEditingController(text: InviteService.pendingCode ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = InviteService.normalize(_codeCtrl.text);
    if (code.isEmpty) {
      showSnack(context, '초대 코드를 입력해 주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await InviteService.redeem(code);
      // approved 면 users 문서가 바뀌어 AuthGate 가 자동으로 넘긴다
      if (mounted && status == 'already') {
        showSnack(context, '이미 승인된 계정이에요. 잠시만 기다려 주세요.');
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
    return Scaffold(
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Icon(Icons.hourglass_top_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '${widget.me.name}님, 승인을 기다리고 있어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '도서관 담당자가 승인하면 바로 쓸 수 있어요.\n'
              '더 빨리 쓰려면 청소년부 선생님이나 도서관 담당자에게\n'
              '초대 코드를 요청해서 아래에 입력하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _redeem(),
              decoration: const InputDecoration(
                labelText: '초대 코드',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _redeem,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('코드 확인'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : AuthService.signOut,
              child: const Text('로그아웃'),
            ),
            const SizedBox(height: 24),
            // 겨자씨 계정이 있는데 다른 계정(예: 다른 Google 계정)으로 들어온 경우 안내
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '청소년부(겨자씨 앱) 계정이 있다면 로그아웃한 뒤 '
                        '겨자씨에서 쓰는 이메일·비밀번호로 로그인하세요. '
                        '승인 없이 바로 쓸 수 있어요.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
