import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/book.dart';

/// books 컬렉션 읽기·쓰기
/// 규칙(mustardseed/firestore.rules): 본인 책만 등록·수정·삭제,
/// 상태는 available ↔ hidden 만 (대여 진행 상태는 함수 전용)
class BookService {
  static CollectionReference<Map<String, dynamic>> get _books =>
      FirebaseFirestore.instance.collection('books');

  /// 서가: 전체 책 (교회 도서관 규모라 한 번에 받아 클라이언트에서 검색·정렬)
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() =>
      _books.limit(1000).snapshots();

  /// 내 책
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMine(String uid) =>
      _books.where('ownerId', isEqualTo: uid).limit(500).snapshots();

  /// 최신 등록 순 정렬 (where + orderBy 금지 규칙 → 클라이언트 정렬)
  static List<Book> sortNewest(Iterable<Book> books) {
    final list = books.toList();
    list.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return -1; // 방금 저장(서버 시간 대기 중)은 맨 위
      if (bt == null) return 1;
      return bt.compareTo(at);
    });
    return list;
  }

  /// 새 책 등록 → 만들어진 책 문서 ID
  static Future<String> add(Book book) async {
    final ref = await _books.add({
      ...book.toFields(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> update(Book book) {
    final fields = book.toFields()..remove('ownerId');
    return _books.doc(book.id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setStatus(String bookId, String status) {
    return _books.doc(bookId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String bookId) => _books.doc(bookId).delete();

  // ── 기증
  /// "기증하기" 켜기·끄기 — 켜 둔 책은 신청하면 대여가 아니라 기증 절차로 진행된다.
  /// 켤 때는 신청을 받을 수 있게 대여 가능 상태로 함께 바꾼다.
  static Future<void> setGiveaway(String bookId, bool on) {
    return _books.doc(bookId).update({
      'giveaway': on,
      if (on) 'status': BookStatus.available,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// 기증 되돌리기 (도서관 관리자) → 다시 소장자가 된 사람 이름
  static Future<String> revertDonation(String bookId) async {
    final res = await _fn
        .httpsCallable('donateBook')
        .call({'action': 'revert', 'bookId': bookId});
    return (res.data as Map)['ownerName']?.toString() ?? '';
  }

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }
}
