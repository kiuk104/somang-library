import 'package:firebase_auth/firebase_auth.dart';

import 'push_service.dart';

/// 로그인 / 가입 / 로그아웃 — 계정은 겨자씨와 같다
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Google 로그인 — 웹 전용 앱이라 팝업 방식만 쓴다
  /// (redirect 방식은 iOS Safari 에서 다른 도메인일 때 잘 깨진다)
  static Future<void> signInWithGoogle() {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithPopup(provider);
  }

  static Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// 로그아웃 — 이 기기의 푸시 토큰을 먼저 지운다 (공용 기기 대비)
  static Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await PushService.forget(uid);
    await _auth.signOut();
  }

  static bool isCancelled(FirebaseAuthException e) =>
      e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request';

  static String messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요. 로그인해 주세요.\n(겨자씨 계정도 같은 이메일로 로그인돼요)';
      case 'weak-password':
        return '비밀번호는 6자리 이상이어야 해요.';
      case 'account-exists-with-different-credential':
        return '이 이메일은 비밀번호로 가입되어 있어요.\n이메일·비밀번호로 로그인해 주세요.';
      case 'popup-blocked':
        return '팝업이 차단되었어요. 팝업을 허용한 뒤 다시 시도해 주세요.';
      case 'operation-not-allowed':
        return '이 로그인 방법이 아직 켜져 있지 않아요. 담당자에게 알려 주세요.';
      case 'too-many-requests':
        return '시도가 너무 많아요. 잠시 후 다시 해 주세요.';
      case 'network-request-failed':
        return '인터넷 연결을 확인해 주세요.';
      default:
        return '문제가 생겼어요. (${e.code})';
    }
  }
}
