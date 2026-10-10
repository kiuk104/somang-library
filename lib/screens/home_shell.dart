import 'dart:async';

import 'package:flutter/material.dart';

import '../models/library_user.dart';
import '../models/loan.dart';
import '../services/loan_service.dart';
import '../services/push_service.dart';
import '../widgets/page_frame.dart';
import 'books/my_books_tab.dart';
import 'books/shelf_tab.dart';
import 'loans/loans_tab.dart';
import 'profile_tab.dart';

/// 도서관 메인 — 서가 / 내 책 / 대여 / 내 정보
/// 대여 목록·알림함은 여기서 한 번만 구독해 대여 탭과 배지에 함께 쓴다.
class HomeShell extends StatefulWidget {
  final LibraryUser me;
  const HomeShell({super.key, required this.me});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // 푸시 알림을 눌러 들어오면 ?tab=loans → 대여 탭
  int _index = Uri.base.queryParameters['tab'] == 'loans' ? 2 : 0;

  List<Loan>? _loans;
  Object? _loansError;
  List<LibraryNotice> _notices = const [];
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    final uid = widget.me.uid;
    _subs.add(LoanService.watchMine(uid).listen(
      (l) => setState(() {
        _loans = l;
        _loansError = null;
      }),
      onError: (Object e) => setState(() => _loansError = e),
    ));
    _subs.add(LoanService.watchNotices(uid).listen(
      (n) => setState(() => _notices = n),
      onError: (_) {},
    ));
    // 앱이 열려 있을 때 온 푸시 → 스낵바
    _subs.add(PushService.onMessage.listen((m) {
      final n = m.notification;
      if (n != null && mounted) {
        showSnack(context, [n.title, n.body].whereType<String>().join('\n'));
      }
    }, onError: (_) {}));
    PushService.refresh(uid);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// 내가 처리해야 할 대여 (받은 신청 + 이번 주일 주고받기)
  int get _todo {
    final uid = widget.me.uid;
    return (_loans ?? const <Loan>[])
        .where((l) =>
            (l.status == LoanStatus.requested && l.ownerId == uid) ||
            l.status == LoanStatus.accepted)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ShelfTab(me: widget.me, notices: _notices),
      MyBooksTab(me: widget.me),
      LoansTab(
        me: widget.me,
        loans: _loans,
        loansError: _loansError,
        notices: _notices,
      ),
      ProfileTab(me: widget.me),
    ];
    final todo = _todo;

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: '서가',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '내 책',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: todo > 0,
              label: Text('$todo'),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
            label: '대여',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
