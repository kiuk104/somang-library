import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app_theme.dart';
import 'screens/auth_gate.dart';
import 'services/invite_service.dart';
import 'utils/web_platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS 는 CPU 렌더링(index.html 참고)이라 느리므로 3x 화면을 2x 로 그린다.
  // 글씨가 아주 약간 덜 선명해지는 대신 그릴 픽셀이 절반 가까이 줄어든다.
  if (WebPlatform.lowDpr) {
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    if (dpr > 2) ui_web.debugOverrideDevicePixelRatio(2.0);
  }
  // 이미지 디코딩 캐시 상한 (기본 100MB). iOS Safari 는 탭 메모리가 넉넉하지
  // 않아 강제 종료되기 쉬우므로 낮게 잡는다 (겨자씨와 같은 대책).
  PaintingBinding.instance.imageCache.maximumSizeBytes = 32 << 20; // 32MB
  PaintingBinding.instance.imageCache.maximumSize = 200;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 초대 링크(?invite=CODE)로 들어왔으면 코드를 기억해 둔다
  InviteService.captureFromUrl();
  runApp(const SomangLibraryApp());
}

class SomangLibraryApp extends StatelessWidget {
  const SomangLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '소망 도서관',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
