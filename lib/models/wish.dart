import 'package:cloud_firestore/cloud_firestore.dart';

/// 희망 도서 상태 — 바꾸는 건 wishAction 함수만
class WishStatus {
  static const open = 'open'; // 아직 서가에 없음
  static const fulfilled = 'fulfilled'; // 누군가 "저 있어요"로 등록함
}

/// library_wishes/{wishId} — 서가에 없는 책을 "읽고 싶어요"로 올려 둔 것
class Wish {
  final String id;
  final String userId;
  final String userName; // 교인은 users 를 못 읽으므로 이름을 복사해 둔다
  final String title;
  final String author;
  final String publisher;
  final String isbn;
  final String coverUrl;
  final String note; // 한마디 (왜 읽고 싶은지 등)
  final List<String> voters; // "저도 읽고 싶어요"를 누른 사람 uid
  final String status;
  final String bookId; // 등록된 책 (fulfilled 일 때)
  final String fulfilledByName;
  final DateTime? createdAt;
  final DateTime? fulfilledAt;

  const Wish({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    this.author = '',
    this.publisher = '',
    this.isbn = '',
    this.coverUrl = '',
    this.note = '',
    this.voters = const [],
    this.status = WishStatus.open,
    this.bookId = '',
    this.fulfilledByName = '',
    this.createdAt,
    this.fulfilledAt,
  });

  bool get isOpen => status == WishStatus.open;

  /// 읽고 싶어 하는 사람 수 (올린 사람 + 공감한 사람)
  int get wantCount => 1 + voters.length;

  bool votedBy(String uid) => voters.contains(uid);

  factory Wish.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String key) => d[key]?.toString() ?? '';
    DateTime? t(String key) {
      final v = d[key];
      return v is Timestamp ? v.toDate() : null;
    }

    final rawVoters = d['voters'];
    return Wish(
      id: doc.id,
      userId: s('userId'),
      userName: s('userName'),
      title: s('title'),
      author: s('author'),
      publisher: s('publisher'),
      isbn: s('isbn'),
      coverUrl: s('coverUrl'),
      note: s('note'),
      voters: rawVoters is List
          ? [for (final v in rawVoters) v.toString()]
          : const [],
      status: d['status']?.toString() == WishStatus.fulfilled
          ? WishStatus.fulfilled
          : WishStatus.open,
      bookId: s('bookId'),
      fulfilledByName: s('fulfilledByName'),
      createdAt: t('createdAt'),
      fulfilledAt: t('fulfilledAt'),
    );
  }
}
