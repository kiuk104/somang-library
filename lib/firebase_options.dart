// 겨자씨(mustardseed)와 같은 Firebase 프로젝트의 웹 앱 설정.
// 계정(Auth)과 users 컬렉션을 공유하기 위해 같은 값을 쓴다.
// ⚠️ 규칙·Cloud Functions 는 mustardseed 저장소에서만 배포한다.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('소망 도서관은 웹(PWA) 전용입니다.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA-jHS0iL2qw6OeA1zAIzUFq31ZGbmV-Zw',
    appId: '1:351903616224:web:d44fb504d0f0dde6f7d485',
    messagingSenderId: '351903616224',
    projectId: 'mustard-seed-6b9e7',
    authDomain: 'mustard-seed-6b9e7.firebaseapp.com',
    storageBucket: 'mustard-seed-6b9e7.firebasestorage.app',
  );
}
