import 'package:cloud_firestore/cloud_firestore.dart';

/// 대여 상태 (loans/{loanId}.status) — 바꾸는 건 loanAction 함수만
class LoanStatus {
  static const requested = 'requested'; // 신청
  static const accepted = 'accepted'; // 수락 → 주일에 주고받기
  static const lent = 'lent'; // 빌려 간 상태
  static const returned = 'returned';
  static const rejected = 'rejected';
  static const canceled = 'canceled';

  static String label(String s) {
    switch (s) {
      case requested:
        return '신청';
      case accepted:
        return '주고받기 예정';
      case lent:
        return '대여 중';
      case returned:
        return '반납 완료';
      case rejected:
        return '거절됨';
      case canceled:
        return '취소됨';
      default:
        return s;
    }
  }
}

/// 주고받는 장소 (기본 선택지 + 직접 입력)
class LoanPlaces {
  static const presets = <({String name, String hint})>[
    (name: '게마인데잘', hint: '청소년부 예배 장소에서 직접 주고받기'),
    (name: '대여 서재', hint: '교회 사무실 옆 대여 서재에 두기'),
    (name: '대예배실 앞', hint: '예배 전후 대예배실 앞에서'),
  ];
}

class Loan {
  final String id;
  final String bookId;
  final String bookTitle;
  final String bookCover;
  final String ownerId;
  final String ownerName;
  final String borrowerId;
  final String borrowerName;
  final String status;
  final String message;
  final String handoverPlace;
  final String returnPlace;
  final String handoverDate; // 'YYYY-MM-DD' (주일)
  final String dueDate; // 'YYYY-MM-DD' (주일)
  final DateTime? requestedAt;
  final DateTime? updatedAt;

  const Loan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookCover,
    required this.ownerId,
    required this.ownerName,
    required this.borrowerId,
    required this.borrowerName,
    required this.status,
    required this.message,
    required this.handoverPlace,
    required this.returnPlace,
    required this.handoverDate,
    required this.dueDate,
    this.requestedAt,
    this.updatedAt,
  });

  bool get isActive =>
      status == LoanStatus.requested ||
      status == LoanStatus.accepted ||
      status == LoanStatus.lent;

  bool isOwner(String uid) => ownerId == uid;

  /// 반납일이 지났는지 (오늘 날짜 문자열과 비교)
  bool get isOverdue =>
      status == LoanStatus.lent &&
      dueDate.isNotEmpty &&
      dueDate.compareTo(todayYmd()) < 0;

  static String todayYmd() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// '2026-10-11' → '10월 11일 주일'
  static String koSunday(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return ymd;
    return '${int.parse(p[1])}월 ${int.parse(p[2])}일 주일';
  }

  factory Loan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String k) => d[k]?.toString() ?? '';
    DateTime? t(String k) => d[k] is Timestamp ? (d[k] as Timestamp).toDate() : null;
    return Loan(
      id: doc.id,
      bookId: s('bookId'),
      bookTitle: s('bookTitle'),
      bookCover: s('bookCover'),
      ownerId: s('ownerId'),
      ownerName: s('ownerName'),
      borrowerId: s('borrowerId'),
      borrowerName: s('borrowerName'),
      status: s('status'),
      message: s('message'),
      handoverPlace: s('handoverPlace'),
      returnPlace: s('returnPlace'),
      handoverDate: s('handoverDate'),
      dueDate: s('dueDate'),
      requestedAt: t('requestedAt'),
      updatedAt: t('updatedAt'),
    );
  }
}

/// 도서관 알림함 (library_notifications)
class LibraryNotice {
  final String id;
  final String title;
  final String body;
  final String loanId;
  final bool read;
  final DateTime? createdAt;

  const LibraryNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.loanId,
    required this.read,
    this.createdAt,
  });

  factory LibraryNotice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final c = d['createdAt'];
    return LibraryNotice(
      id: doc.id,
      title: d['title']?.toString() ?? '',
      body: d['body']?.toString() ?? '',
      loanId: d['loanId']?.toString() ?? '',
      read: d['read'] == true,
      createdAt: c is Timestamp ? c.toDate() : null,
    );
  }
}
