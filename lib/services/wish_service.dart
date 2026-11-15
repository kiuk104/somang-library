import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/wish.dart';

/// 희망 도서 — 읽기는 library_wishes 직접, 변경은 전부 Cloud Function
/// (wishAction, mustardseed 저장소, europe-west1)
class WishService {
  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// 한 사람이 올려 둘 수 있는 희망 도서 수 — 서버 WISH_MAX_OPEN 과 같은 값
  static const maxOpen = 10;

  /// 들어온 책을 목록에 남겨 두는 기간
  static const keepFulfilledDays = 30;

  /// 희망 도서 전체 (교회 규모라 한 번에 받아 클라이언트에서 정렬)
  static Stream<List<Wish>> watchAll() => FirebaseFirestore.instance
      .collection('library_wishes')
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map(Wish.fromDoc).toList());

  /// 아직 안 들어온 희망 — 읽고 싶은 사람이 많은 순, 같으면 최근 순
  static List<Wish> openSorted(Iterable<Wish> all) {
    final list = all.where((w) => w.isOpen).toList();
    list.sort((a, b) {
      if (a.wantCount != b.wantCount) return b.wantCount.compareTo(a.wantCount);
      return _newer(a.createdAt, b.createdAt);
    });
    return list;
  }

  /// 최근에 들어온 책 (30일 이내, 최근 순)
  static List<Wish> recentFulfilled(Iterable<Wish> all) {
    final since =
        DateTime.now().subtract(const Duration(days: keepFulfilledDays));
    final list = all
        .where((w) =>
            !w.isOpen && (w.fulfilledAt == null || w.fulfilledAt!.isAfter(since)))
        .toList();
    list.sort((a, b) => _newer(a.fulfilledAt, b.fulfilledAt));
    return list;
  }

  static int _newer(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1; // 방금 저장(서버 시간 대기 중)은 맨 위
    if (b == null) return 1;
    return b.compareTo(a);
  }

  static Future<String> _act(Map<String, dynamic> data) async {
    final res = await _fn.httpsCallable('wishAction').call(data);
    return (res.data as Map)['status']?.toString() ?? '';
  }

  /// 희망 도서 올리기 → 'created' | 'voted'(같은 책의 희망이 이미 있어 공감만 더함)
  static Future<String> create({
    required String title,
    String author = '',
    String publisher = '',
    String isbn = '',
    String coverUrl = '',
    String note = '',
  }) =>
      _act({
        'action': 'create',
        'title': title,
        'author': author,
        'publisher': publisher,
        'isbn': isbn,
        'coverUrl': coverUrl,
        'note': note,
      });

  static Future<void> delete(String wishId) =>
      _act({'action': 'delete', 'wishId': wishId});

  /// "저도 읽고 싶어요" 켜기·끄기
  static Future<void> vote(String wishId, bool on) =>
      _act({'action': on ? 'vote' : 'unvote', 'wishId': wishId});

  /// "저 있어요" — 내가 방금 등록한 책을 희망 도서에 연결 (희망한 사람들에게 알림)
  static Future<void> fulfill(String wishId, String bookId) =>
      _act({'action': 'fulfill', 'wishId': wishId, 'bookId': bookId});

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }
}
