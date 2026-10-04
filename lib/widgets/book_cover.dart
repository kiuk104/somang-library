import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/book.dart';

/// 책 표지 — 표지 이미지가 없거나 못 불러오면 제목으로 만든 표지를 보여준다
class BookCover extends StatelessWidget {
  final String coverUrl;
  final String title;
  final double width;

  const BookCover({
    super.key,
    required this.coverUrl,
    required this.title,
    this.width = 64,
  });

  static const _spines = [
    Color(0xFF2F5D50), Color(0xFF7A4E3B), Color(0xFF3E5C76),
    Color(0xFF8C6D2F), Color(0xFF5B4B7A), Color(0xFF4F6B3A),
  ];

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final placeholder = _GeneratedCover(
      title: title,
      color: _spines[title.hashCode.abs() % _spines.length],
      width: width,
      height: height,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.06),
      child: SizedBox(
        width: width,
        height: height,
        child: coverUrl.isEmpty
            ? placeholder
            : Image.network(
                coverUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                // iOS Safari 메모리 대책: 화면 크기만큼만 디코딩
                cacheWidth: (width * dpr).round(),
                // 표지 서버가 CORS 를 안 열어 줘도 <img> 로 대신 그린다
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _GeneratedCover extends StatelessWidget {
  final String title;
  final Color color;
  final double width;
  final double height;

  const _GeneratedCover({
    required this.title,
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color,
      padding: EdgeInsets.all(width * 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, width: width * 0.3, color: AppTheme.bookmark),
          SizedBox(height: width * 0.08),
          Expanded(
            child: Text(
              title,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.paper,
                fontSize: (width * 0.13).clamp(9, 16).toDouble(),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 상태 표시 칩
class BookStatusChip extends StatelessWidget {
  final String status;
  const BookStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = status == BookStatus.available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: available ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        BookStatus.label(status),
        style: TextStyle(
          fontSize: 12,
          color: available ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

}
