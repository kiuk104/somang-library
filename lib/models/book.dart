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

/// 공개 범위 — public: 모든 도서관 사용자 / friends: 서로 친구인 사람만
class BookVisibility {
  static const public = 'public';
  static const friends = 'friends';
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
  final String visibility; // BookVisibility (없으면 public)
  final bool giveaway; // 소장자가 "기증하기"를 켠 책 — 신청하면 대여가 아니라 기증 절차
  final String donatedById; // 기증한 사람 (기증받은 책일 때만, 함수가 쓴다)
  final String donatedByName;
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
    this.visibility = BookVisibility.public,
    this.giveaway = false,
    this.donatedById = '',
    this.donatedByName = '',
    this.createdAt,
  });

  /// 다른 사람에게서 기증받은 책
  bool get isDonated => donatedById.isNotEmpty;

  bool get isAvailable => status == BookStatus.available;
  bool get friendsOnly => visibility == BookVisibility.friends;
  bool get isOwnerEditable =>
      status == BookStatus.available || status == BookStatus.hidden;

  /// 검색용 (제목·저자·소장자)
  String get searchText => '$title $author $ownerName'.toLowerCase();

  /// 제목 끝의 권 번호 — 'Spy x Family 1', '원피스 3권', 'LTB Mystery Band 4', '해리 포터 (2)'
  static final _volumeRe = RegExp(
    r'^(.+?)[\s,.:·\-–(#]*(?:band|bd\.?|vol\.?|volume|nr\.?|no\.?|제)?\s*(?<!\d)(\d{1,3})\s*(?:권|巻|\))?$',
    caseSensitive: false,
  );

  /// 시리즈 이름 (권 번호가 없으면 null) — 서가의 '시리즈 묶기'에 쓴다
  String? get seriesName {
    final m = _volumeRe.firstMatch(title.trim());
    if (m == null) return null;
    final name = m.group(1)!.trim();
    // '1984', 'Psalm 23' 같은 짧은 제목은 묶지 않는다 (글자 2개 이상)
    if (RegExp(r'\p{L}', unicode: true).allMatches(name).length < 2) return null;
    return name;
  }

  /// 권 번호 (없으면 0)
  int get volume {
    if (seriesName == null) return 0;
    return int.tryParse(_volumeRe.firstMatch(title.trim())!.group(2)!) ?? 0;
  }

  /// 같은 시리즈 비교용 (대소문자·띄어쓰기·기호 무시)
  String? get seriesKey => seriesName
      ?.toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

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
      visibility: d['visibility']?.toString() == BookVisibility.friends
          ? BookVisibility.friends
          : BookVisibility.public,
      giveaway: d['giveaway'] == true,
      donatedById: s('donatedById'),
      donatedByName: s('donatedByName'),
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
        'visibility': visibility,
      };
}
