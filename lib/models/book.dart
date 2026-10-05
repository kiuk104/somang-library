import 'package:cloud_firestore/cloud_firestore.dart';

/// 책 상태
/// - available : 대여 가능
/// - hidden    : 소장자가 잠시 숨김 (서가에는 보이지만 신청 불가)
/// - requested / reserved / lent : 대여 진행 (loanAction 함수가 바꾼다)
class BookStatus {
  static const available = 'available';
  static const hidden = 'hidden';
  static const requested = 'requested';
  static const reserved = 'reserved'; // 수락됨, 주일 전달 예정
  static const lent = 'lent';

  static String label(String status) {
    switch (status) {
      case available:
        return '대여 가능';
      case hidden:
        return '대여 쉼';
      case requested:
        return '신청 중';
      case reserved:
        return '전달 예정';
      case lent:
        return '대여 중';
      default:
        return status;
    }
  }
}

/// books/{bookId}
class Book {
  final String id;
  final String ownerId;
  final String ownerName; // 교인은 users 를 못 읽으므로 이름을 복사해 둔다
  final String title;
  final String author;
  final String publisher;
  final String isbn;
  final String coverUrl;
  final String note; // 소장자 메모 (책 상태 등)
  final String status;
  final DateTime? createdAt;

  const Book({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    this.author = '',
    this.publisher = '',
    this.isbn = '',
    this.coverUrl = '',
    this.note = '',
    this.status = BookStatus.available,
    this.createdAt,
  });

  bool get isAvailable => status == BookStatus.available;
  bool get isOwnerEditable =>
      status == BookStatus.available || status == BookStatus.hidden;

  /// 검색용 (제목·저자·소장자)
  String get searchText => '$title $author $ownerName'.toLowerCase();

  factory Book.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String key) => d[key]?.toString() ?? '';
    final created = d['createdAt'];
    return Book(
      id: doc.id,
      ownerId: s('ownerId'),
      ownerName: s('ownerName'),
      title: s('title'),
      author: s('author'),
      publisher: s('publisher'),
      isbn: s('isbn'),
      coverUrl: s('coverUrl'),
      note: s('note'),
      status: d['status']?.toString() ?? BookStatus.available,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// 저장용 — 규칙상 문자열 필드에 null 을 넣으면 안 된다 (빈 문자열 사용)
  Map<String, dynamic> toFields() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'title': title,
        'author': author,
        'publisher': publisher,
        'isbn': isbn,
        'coverUrl': coverUrl,
        'note': note,
        'status': status,
      };
}
