import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../services/push_service.dart';
import 'page_frame.dart';

/// "알림 켜기" 안내 카드 — 이미 켰거나 설정 전(VAPID 키 없음)이면 보이지 않는다
class PushCard extends StatefulWidget {
  const PushCard({super.key});

  @override
  State<PushCard> createState() => _PushCardState();
}

class _PushCardState extends State<PushCard> {
  bool? _supported;
  bool _enabled = true; // 확인 전에는 숨김
  bool _busy = false;

  bool get _isIphone {
    final nav = web.window.navigator;
    // iPadOS 는 'Macintosh' 로 보고되므로 터치 지원 여부로 구분
    return RegExp('iPhone|iPad|iPod').hasMatch(nav.userAgent) ||
        (nav.platform == 'MacIntel' && nav.maxTouchPoints > 1);
  }

  @override
  void initState() {
    super.initState();
    PushService.enabled.addListener(_onShared);
    _check();
  }

  @override
  void dispose() {
    PushService.enabled.removeListener(_onShared);
    super.dispose();
  }

  // 다른 화면에서 알림을 켜면 이 카드도 숨긴다
  void _onShared() {
    final v = PushService.enabled.value;
    if (v != null && mounted) setState(() => _enabled = v);
  }

  Future<void> _check() async {
    final supported = await PushService.isSupported();
    final enabled = supported && await PushService.isEnabled();
    if (mounted) {
      setState(() {
        _supported = supported;
        _enabled = enabled;
      });
    }
  }

  Future<void> _enable() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    final error = await PushService.enable(uid);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      setState(() => _enabled = true);
      showSnack(context, '알림을 켰어요! 신청·수락·반납 소식을 알려 드릴게요.');
    } else {
      showSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PushService.configured || _supported == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    // 아이폰 Safari 탭에서는 알림이 안 됨 → 홈 화면 추가 안내
    if (_supported == false) {
      if (!_isIphone) return const SizedBox.shrink();
      return Card(
        color: theme.colorScheme.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            '📲 알림을 받으려면: Safari 아래 공유 버튼 → "홈 화면에 추가" → '
            '홈 화면의 소망 도서관 아이콘으로 열어서 알림을 켜 주세요.',
          ),
        ),
      );
    }
    if (_enabled) return const SizedBox.shrink();

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('대여 신청·수락·반납일을 알림으로 받아 보세요.'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _busy ? null : _enable,
              child: const Text('알림 켜기'),
            ),
          ],
        ),
      ),
    );
  }
}
