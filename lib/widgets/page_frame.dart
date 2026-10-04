import 'package:flutter/material.dart';

/// 넓은 화면에서도 가운데 폭 560 으로 모아 보여주는 틀 (내용은 위쪽부터)
class PageFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scroll;

  const PageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: scroll ? SingleChildScrollView(child: body) : body,
        ),
      ),
    );
  }
}

/// 앱 로고 (아이콘 + 이름)
class LibraryLogo extends StatelessWidget {
  final double size;
  const LibraryLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      // web/icons 의 PWA 아이콘을 그대로 쓴다 (Flutter assets 가 아니라 network 경로)
      child: Image.network(
        'icons/Icon-192.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => Icon(
          Icons.menu_book_rounded,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// 스낵바 한 줄
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
