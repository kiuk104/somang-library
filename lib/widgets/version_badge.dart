import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 앱 버전 표시 — `flutter build web` 이 만드는 `version.json` 을 읽는다
/// (pubspec.yaml 의 version: x.y.z+YYYYMMDD → "vx.y.z (YY.MM.DD)").
/// 겨자씨 앱의 VersionBadge 와 같은 형식. 추가 패키지 없이 http 로 읽는다.
class VersionBadge extends StatefulWidget {
  const VersionBadge({super.key});

  @override
  State<VersionBadge> createState() => _VersionBadgeState();
}

class _VersionBadgeState extends State<VersionBadge> {
  static String? _cached; // 한 번 읽으면 세션 동안 재사용
  String? _label;

  @override
  void initState() {
    super.initState();
    _label = _cached;
    if (_label == null) _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.base.resolve('version.json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final version = (map['version'] ?? '').toString();
      final build = (map['build_number'] ?? '').toString();
      if (version.isEmpty) return;
      _cached = 'v$version${build.isEmpty ? '' : ' (${_formatBuildDate(build)})'}';
      if (mounted) setState(() => _label = _cached);
    } catch (_) {
      // 버전 표시는 부가 정보 — 실패해도 조용히 넘어간다
    }
  }

  /// 20261010 → 26.10.10 (8자리가 아니면 그대로)
  static String _formatBuildDate(String build) {
    if (build.length != 8) return build;
    return '${build.substring(2, 4)}.${build.substring(4, 6)}.${build.substring(6, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
