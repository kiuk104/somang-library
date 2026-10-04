import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/library_user.dart';
import '../services/auth_service.dart';
import '../widgets/page_frame.dart';
import 'login_screen.dart';
import 'join_screen.dart';
import 'pending_screen.dart';
import 'home_shell.dart';

/// 로그인 상태와 users 문서를 보고 어느 화면을 보여줄지 정한다.
///
///   로그인 안 함            → LoginScreen
///   로그인 + users 문서 없음 → JoinScreen   (처음 온 교인: 이름·초대 코드)
///   교인 + 미승인            → PendingScreen
///   그 외                    → HomeShell
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        // uid 가 바뀌면 문서 구독도 새로 만들도록 key 지정
        return _UserDocGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _UserDocGate extends StatefulWidget {
  final String uid;
  const _UserDocGate({super.key, required this.uid});

  @override
  State<_UserDocGate> createState() => _UserDocGateState();
}

class _UserDocGateState extends State<_UserDocGate> {
  // build() 안에서 snapshots() 를 새로 만들지 않는다 (겨자씨 성능 규칙과 동일)
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream =
      FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorScreen(message: '계정 정보를 불러오지 못했어요.\n${snapshot.error}');
        }
        if (!snapshot.hasData) return const LoadingScreen();

        final doc = snapshot.data!;
        if (!doc.exists) return const JoinScreen();

        final me = LibraryUser.fromDoc(doc);
        if (!me.canUseLibrary) return PendingScreen(me: me);
        return HomeShell(me: me);
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageFrame(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: AuthService.signOut,
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
