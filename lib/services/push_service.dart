import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 웹 푸시 (Firebase Cloud Messaging)
///
/// - 토큰은 users/{uid}/libraryTokens/{token} 에 저장 → loanAction 함수가 보낸다
/// - 아이폰은 Safari 에서 "홈 화면에 추가"한 앱에서만 알림을 받을 수 있다 (iOS 16.4+)
/// - 백그라운드 알림 표시는 web/firebase-messaging-sw.js
class PushService {
  /// Firebase 콘솔 → 프로젝트 설정 → 클라우드 메시징 → 웹 푸시 인증서 → 키 쌍 (공개 키)
  /// 비어 있으면 알림 켜기 버튼을 숨긴다.
  static const vapidKey = '';

  static bool get configured => vapidKey.isNotEmpty;

  /// 알림이 켜졌는지 — 여러 화면의 "알림 켜기" 카드가 함께 본다 (null: 확인 전)
  static final ValueNotifier<bool?> enabled = ValueNotifier<bool?>(null);

  static Future<bool> isSupported() async {
    if (!configured) return false;
    try {
      return await FirebaseMessaging.instance.isSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    if (!await isSupported()) return false;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    final on = s.authorizationStatus == AuthorizationStatus.authorized;
    enabled.value = on;
    return on;
  }

  /// 알림 켜기 (버튼을 눌렀을 때만 — 브라우저 정책). 실패하면 이유 문자열
  static Future<String?> enable(String uid) async {
    if (!await isSupported()) {
      return '이 브라우저에서는 알림을 받을 수 없어요.\n아이폰은 Safari 공유 버튼 → "홈 화면에 추가" 후 그 앱에서 켜 주세요.';
    }
    final s = await FirebaseMessaging.instance.requestPermission();
    if (s.authorizationStatus != AuthorizationStatus.authorized) {
      return '알림이 허용되지 않았어요. 브라우저 설정에서 이 사이트의 알림을 허용해 주세요.';
    }
    if (!await _saveToken(uid)) return '알림 등록에 실패했어요. 잠시 후 다시 시도해 주세요.';
    enabled.value = true;
    return null;
  }

  /// 이미 허용된 경우 앱을 열 때마다 토큰 갱신 (토큰은 바뀔 수 있다)
  static Future<void> refresh(String uid) async {
    try {
      if (await isEnabled()) await _saveToken(uid);
    } catch (_) {}
  }

  static Future<bool> _saveToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      if (token == null || token.isEmpty) return false;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('libraryTokens')
          .doc(token)
          .set({'updatedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 로그아웃 전에: 이 기기 토큰을 지워서 다음 사람에게 내 알림이 가지 않게
  static Future<void> forget(String uid) async {
    try {
      if (!await isEnabled()) return;
      final token = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('libraryTokens')
            .doc(token)
            .delete();
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  /// 앱이 열려 있을 때 온 알림 (화면 위 스낵바로 보여준다)
  static Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
