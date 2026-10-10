import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app_theme.dart';
import 'screens/auth_gate.dart';
import 'services/invite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
