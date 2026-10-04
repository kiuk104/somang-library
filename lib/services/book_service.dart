import 'package:cloud_firestore/cloud_firestore.dart';

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

  static Future<void> add(Book book) {
    return _books.add({
      ...book.toFields(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
}
