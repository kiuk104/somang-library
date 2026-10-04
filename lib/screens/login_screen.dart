import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/invite_service.dart';
import '../widgets/page_frame.dart';

/// 로그인 / 이메일 가입
/// 로그인에 성공하면 AuthGate 가 알아서 다음 화면으로 넘긴다 (여기서 이동하지 않음)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isSignUp = false; // false: 로그인, true: 이메일로 새로 가입
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  /// 성공하면 true
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e) {
      if (!AuthService.isCancelled(e) && mounted) {
        showSnack(context, AuthService.messageFor(e));
      }
    } catch (e) {
      if (mounted) showSnack(context, '문제가 생겼어요. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  void _submitEmail() {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      showSnack(context, '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    _run(() => _isSignUp
        ? AuthService.signUpWithEmail(email, pw)
        : AuthService.signInWithEmail(email, pw));
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      showSnack(context, '위에 이메일을 먼저 입력해 주세요.');
      return;
    }
    final ok = await _run(() => AuthService.sendPasswordReset(email));
    if (ok && mounted) showSnack(context, '$email 로 비밀번호 재설정 메일을 보냈어요.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = InviteService.pendingCode;

    return Scaffold(
      body: PageFrame(
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Center(child: LibraryLogo(size: 84)),
              const SizedBox(height: 20),
              Text(
                '소망 도서관',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '베를린 소망교회 · 책을 나누는 작은 도서관',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              if (code != null) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.mark_email_read_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '초대 코드 $code 를 받았어요.\n로그인하거나 가입하면 다음 화면에 코드가 미리 들어가 있어요.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Google 로그인 — 가장 간단한 방법이라 맨 위에
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(AuthService.signInWithGoogle),
                icon: const Text('G',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                label: const Text('Google로 계속하기'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('또는 이메일',
                        style: TextStyle(color: theme.colorScheme.outline)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: '이메일',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwCtrl,
                obscureText: true,
                autofillHints: [
                  _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
                ],
                onSubmitted: (_) => _submitEmail(),
                decoration: InputDecoration(
                  labelText: _isSignUp ? '비밀번호 (6자리 이상)' : '비밀번호',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submitEmail,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_isSignUp ? '이메일로 가입하기' : '로그인'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp
                    ? '이미 계정이 있어요 — 로그인'
                    : '처음이에요 — 이메일로 가입'),
              ),
              if (!_isSignUp)
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('비밀번호를 잊었어요'),
                ),
              const SizedBox(height: 16),
              Text(
                '겨자씨 앱 계정이 있다면 같은 이메일로 로그인하세요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
