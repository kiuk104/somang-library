import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/book.dart';
import '../utils/web_platform.dart';

/// 시트·대화상자(배경이 어두워지는 팝업)가 떠 있는 동안 뒤쪽 표지 이미지를 숨기는 장치.
///
/// 표지 서버가 CORS 를 안 열어 주면 표지가 <img> HTML 요소로 그려지는데(아래 webHtmlElementStrategy),
/// 이 요소는 Flutter 화면 위에 따로 떠 있어서 시트가 뒤쪽 표지를 가려 주지 못하고
/// 서가의 표지가 시트 버튼 위로 비쳐 보인다. 그래서 팝업이 떠 있는 동안에는
/// 팝업 뒤의 표지를 빈 칸으로 바꾸고, 맨 위 팝업 안의 표지만 그린다.
/// MaterialApp.navigatorObservers 에 [CoverOverlay.observer] 를 꼭 넣어야 한다.
class CoverOverlay {
  static final List<Route<dynamic>> _stack = [];
  static final ValueNotifier<int> _tick = ValueNotifier(0);

  static final NavigatorObserver observer = _CoverOverlayObserver();

  /// 이 context 의 표지를 지금 그려도 되는지
  static bool visibleFor(BuildContext context) {
    if (_stack.isEmpty) return true;
    final route = ModalRoute.of(context);
    return route != null && identical(route, _stack.last);
  }

  static void _notify() {
    // 네비게이터가 화면을 바꾸는 도중에 호출되므로 다음 순간에 알린다
    scheduleMicrotask(() => _tick.value++);
  }
}

class _CoverOverlayObserver extends NavigatorObserver {
  /// 배경이 어두워지는 팝업(시트·대화상자)만 — 팝업 메뉴(barrierColor 없음)는 제외
  bool _isScrimPopup(Route<dynamic> route) =>
      route is PopupRoute && route.barrierColor != null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isScrimPopup(route)) return;
    CoverOverlay._stack.add(route);
    CoverOverlay._notify();
    // 닫히는 애니메이션이 다 끝난 뒤에 뒤쪽 표지를 되살린다
    if (route is TransitionRoute) {
      route.completed.whenComplete(() {
        CoverOverlay._stack.remove(route);
        CoverOverlay._notify();
      });
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (CoverOverlay._stack.remove(route)) CoverOverlay._notify();
  }
}

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
        child: coverUrl.isEmpty || WebPlatform.noCovers
            ? placeholder
            : ValueListenableBuilder<int>(
                valueListenable: CoverOverlay._tick,
                builder: (context, _, _) => !CoverOverlay.visibleFor(context)
                    ? ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest)
                    : _image(dpr, placeholder),
              ),
      ),
    );
  }

  Widget _image(double dpr, Widget placeholder) {
    final height = width * 1.5;
    return Image.network(
                coverUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                // iOS Safari 메모리 대책: 화면 크기만큼만 디코딩
                cacheWidth: (width * dpr).round(),
                // iPhone/iPad(WebKit): CanvasKit 이 이미지를 디코딩해 WebGL 텍스처로
                // 올리는 경로가 Safari 의 탭 메모리 상한을 쉽게 넘겨 페이지가 강제
                // 종료된다 (flutter/flutter#152709). Safari 는 <img> 요소를 따로
                // 최적화하므로 iOS 에서는 항상 <img> 로 그린다 (prefer).
                // 그 외 플랫폼: 표지 서버가 CORS 를 안 열어 줄 때만 <img> (fallback).
                webHtmlElementStrategy:
                    WebPlatform.isIosWebKit && !WebPlatform.imgCoversOff
                        ? WebHtmlElementStrategy.prefer
                        : WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => placeholder,
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

/// 책 상태별 색 — 서가 배지·내 책·상세 칩이 같은 색을 쓴다
/// 대여 가능은 차분한 초록, 신청 중은 노랑, 전달 예정은 파랑, 대여 중은 진한 적갈색, 쉼은 회색
({Color bg, Color fg}) bookStatusColors(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case BookStatus.available:
      return (bg: scheme.primaryContainer, fg: scheme.onPrimaryContainer);
    case BookStatus.requested:
      return (bg: const Color(0xFFFFE1A6), fg: const Color(0xFF5C3B00));
    case BookStatus.reserved:
      return (bg: const Color(0xFFCFE3FF), fg: const Color(0xFF0B3A6B));
    case BookStatus.lent:
      return (bg: const Color(0xFF8A3F3F), fg: Colors.white);
    default: // hidden(대여 쉼) 등
      return (bg: scheme.surfaceContainerHighest, fg: scheme.onSurfaceVariant);
  }
}

/// 표지 모서리에 붙이는 작은 상태 배지 (대여 가능이 아닐 때만 쓴다)
class BookStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  const BookStatusBadge({super.key, required this.status, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final c = bookStatusColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        BookStatus.label(status),
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: c.fg,
          height: 1.1,
        ),
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
    final c = bookStatusColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        BookStatus.label(status),
        style: TextStyle(fontSize: 12, color: c.fg),
      ),
    );
  }
}
