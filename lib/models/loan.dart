import 'package:cloud_firestore/cloud_firestore.dart';

/// 대여 상태 (loans/{loanId}.status) — 바꾸는 건 loanAction 함수만
class LoanStatus {
  static const requested = 'requested'; // 신청
  static const accepted = 'accepted'; // 수락 → 주일에 주고받기
  static const lent = 'lent'; // 빌려 간 상태
  static const returned = 'returned';
  static const given = 'given'; // 기증 완료 — 책이 받은 사람의 것이 됨
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
      case given:
        return '기증 완료';
      case rejected:
        return '거절됨';
      case canceled:
        return '취소됨';
      default:
        return s;
    }
  }
}

/// 신청 가능 권수 — 동시에 신청·수락·대여 중인 책의 한도
/// 기본 3권, 공개한 책(대여 쉼 제외) 3권마다 +1권, 최대 10권. 도서관 관리자는 무제한.
/// 서버(mustardseed functions/index.js 의 LOAN_LIMIT_*)와 같은 값을 쓴다 — 바꾸면 둘 다 고칠 것.
class LoanQuota {
  static const base = 3;
  static const step = 3;
  static const max = 10;

  static int limitFor(int sharedBooks) {
    final v = base + sharedBooks ~/ step;
    return v > max ? max : v;
  }

  /// 연체 페널티 — 연체 중이면 새 신청 불가, 늦게 반납했다면 늦은 일수만큼(최대 28일) 신청 정지
  /// 서버의 LOAN_PENALTY_MAX_DAYS 와 같은 값. [mine] 은 내가 빌린 대여 건.
  static const penaltyMaxDays = 28;

  static ({String? overdueTitle, String? blockedUntil}) penaltyFor(
      Iterable<Loan> mine) {
    final today = Loan.todayYmd();
    String? overdueTitle;
    String? until;
    for (final l in mine) {
      if (l.dueDate.isEmpty) continue;
      if (l.isOverdue) {
        overdueTitle ??= l.bookTitle;
        continue;
      }
      // "반납했어요"를 누른 날이 있으면 그날을 반납한 날로 본다 (서버와 같은 계산)
      final r = l.returnReportedAt ??
          (l.status == LoanStatus.returned ? l.returnedAt : null);
      if ((l.status == LoanStatus.returned || l.status == LoanStatus.lent) &&
          r != null) {
        final ret = Loan.ymdOf(r);
        if (ret.compareTo(l.dueDate) > 0) {
          final late =
              DateTime.parse(ret).difference(DateTime.parse(l.dueDate)).inDays;
          final days = late > penaltyMaxDays ? penaltyMaxDays : late;
          final end = Loan.ymdOf(DateTime.parse(ret).add(Duration(days: days)));
          if (end.compareTo(today) > 0 &&
              (until == null || end.compareTo(until) > 0)) {
            until = end;
          }
        }
      }
    }
    return (overdueTitle: overdueTitle, blockedUntil: until);
  }

  /// 다음 +1권까지 더 공개해야 하는 책 수 (최대 한도면 null)
  static int? booksToNext(int sharedBooks) {
    if (limitFor(sharedBooks) >= max) return null;
    return step - sharedBooks % step;
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
  final String handoverTime; // 선택: '예배 후', '12:30' 등
  final String returnTime;
  final String handoverDate; // 'YYYY-MM-DD' (주일)
  final String dueDate; // 'YYYY-MM-DD' (주일)
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final DateTime? returnedAt; // 반납 완료 시각 (연체 페널티 계산용)
  final DateTime? returnReportedAt; // 빌린 사람이 "반납했어요"를 누른 시각 (소장자 확인 전)
  final bool gift; // 기증 건 — 절차는 대여와 같고, 주고받으면 책이 받은 사람의 것이 된다

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
    this.handoverTime = '',
    this.returnTime = '',
    required this.handoverDate,
    required this.dueDate,
    this.requestedAt,
    this.updatedAt,
    this.returnedAt,
    this.returnReportedAt,
    this.gift = false,
  });

  /// 빌린 사람은 반납했다고 알렸는데 소장자가 아직 확인하지 않은 상태
  bool get returnReported =>
      status == LoanStatus.lent && returnReportedAt != null;

  bool get isActive =>
      status == LoanStatus.requested ||
      status == LoanStatus.accepted ||
      status == LoanStatus.lent;

  bool isOwner(String uid) => ownerId == uid;

  /// 반납일이 지났는지 (오늘 날짜 문자열과 비교) — 반납했다고 알린 건은 연체로 보지 않는다
  bool get isOverdue =>
      status == LoanStatus.lent &&
      returnReportedAt == null &&
      dueDate.isNotEmpty &&
      dueDate.compareTo(todayYmd()) < 0;

  static String todayYmd() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// '2026-10-11' → '10월 11일 주일', '2026-10-14' → '10월 14일(수)'
  static String koDate(String ymd) {
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    if (d.weekday == DateTime.sunday) return '${d.month}월 ${d.day}일 주일';
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일(${names[d.weekday - 1]})';
  }

  /// 날짜 + 시간 ('10월 11일 주일 · 예배 후')
  static String koWhen(String ymd, String time) =>
      time.isEmpty ? koDate(ymd) : '${koDate(ymd)} · $time';

  static String ymdOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      handoverTime: s('handoverTime'),
      returnTime: s('returnTime'),
      handoverDate: s('handoverDate'),
      dueDate: s('dueDate'),
      requestedAt: t('requestedAt'),
      updatedAt: t('updatedAt'),
      returnedAt: t('returnedAt'),
      returnReportedAt: t('returnReportedAt'),
      gift: d['gift'] == true,
    );
  }
}

/// 도서관 알림함 (library_notifications)
class LibraryNotice {
  final String id;
  final String title;
  final String body;
  final String loanId;
  final String type; // 'friend_request' 등
  final String fromId; // 알림을 일으킨 사람 uid (친구 신청 알림만)
  final bool read;
  final DateTime? createdAt;

  const LibraryNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.loanId,
    this.type = '',
    this.fromId = '',
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
      type: d['type']?.toString() ?? '',
      fromId: d['fromId']?.toString() ?? '',
      read: d['read'] == true,
      createdAt: c is Timestamp ? c.toDate() : null,
    );
  }
}

/// 대기 신청 (library_waitlist) — 이미 신청·대여 중인 책이 나오면 알림을 받는다
/// 만들기·지우기는 loanAction(wait/unwait/request) 함수만 한다.
class WaitEntry {
  final String id;
  final String bookId;
  final String bookTitle;
  final String bookCover;
  final String ownerId;
  final String ownerName;
  final String userId;
  final String userName;
  final DateTime? createdAt;

  const WaitEntry({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookCover,
    required this.ownerId,
    required this.ownerName,
    required this.userId,
    required this.userName,
    this.createdAt,
  });

  factory WaitEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String k) => d[k]?.toString() ?? '';
    final c = d['createdAt'];
    return WaitEntry(
      id: doc.id,
      bookId: s('bookId'),
      bookTitle: s('bookTitle'),
      bookCover: s('bookCover'),
      ownerId: s('ownerId'),
      ownerName: s('ownerName'),
      userId: s('userId'),
      userName: s('userName'),
      createdAt: c is Timestamp ? c.toDate() : null,
    );
  }
}
