import 'package:flutter/material.dart';

import '../models/library_user.dart';
import 'profile_tab.dart';
import 'books/shelf_tab.dart';
import 'books/my_books_tab.dart';

/// 도서관 메인 — 아래 탭 4개
/// 대여 탭은 다음 단계에서 채운다.
class HomeShell extends StatefulWidget {
  final LibraryUser me;
  const HomeShell({super.key, required this.me});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ShelfTab(me: widget.me),
      MyBooksTab(me: widget.me),
      const _ComingSoon(
        icon: Icons.swap_horiz_rounded,
        title: '대여',
        description: '빌린 책·빌려준 책과 신청 현황을 봐요.\n주고받기는 주일에 교회에서!',
      ),
      ProfileTab(me: widget.me),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: '서가',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '내 책',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: '대여',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}

/// 아직 만들지 않은 탭 자리
class _ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text('곧 만들어져요',
                  style: TextStyle(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
