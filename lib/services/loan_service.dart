import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/loan.dart';

/// 대여 처리 — 상태 변경은 모두 Cloud Function loanAction (mustardseed 저장소, europe-west1)
class LoanService {
  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final res = await _fn.httpsCallable('loanAction').call(data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<void> request(String bookId,
          {String handoverPlace = '', String message = ''}) =>
      _call({
        'action': 'request',
        'bookId': bookId,
        'handoverPlace': handoverPlace,
        'message': message,
      });

  static Future<void> accept(String loanId,
          {required String handoverPlace, required String returnPlace}) =>
      _call({
        'action': 'accept',
        'loanId': loanId,
        'handoverPlace': handoverPlace,
        'returnPlace': returnPlace,
      });

  static Future<void> reject(String loanId) =>
      _call({'action': 'reject', 'loanId': loanId});

  static Future<void> cancel(String loanId) =>
      _call({'action': 'cancel', 'loanId': loanId});

  static Future<void> handover(String loanId) =>
      _call({'action': 'handover', 'loanId': loanId});

  /// 이미 신청·대여 중인 책 대기 신청 / 취소 (책이 나오면 알림)
  static Future<void> wait(String bookId) =>
      _call({'action': 'wait', 'bookId': bookId});

  static Future<void> unwait(String bookId) =>
      _call({'action': 'unwait', 'bookId': bookId});

  static List<WaitEntry> _waitList(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(WaitEntry.fromDoc).toList();
    list.sort((a, b) {
      final at = a.createdAt, bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt); // 먼저 기다린 순
    });
    return list;
  }

  /// 내가 기다리는 책
  static Stream<List<WaitEntry>> watchMyWaits(String uid) =>
      FirebaseFirestore.instance
          .collection('library_waitlist')
          .where('userId', isEqualTo: uid)
          .limit(50)
          .snapshots()
          .map(_waitList);

  /// 내 책을 기다리는 사람들
  static Stream<List<WaitEntry>> watchWaitsOnMyBooks(String uid) =>
      FirebaseFirestore.instance
          .collection('library_waitlist')
          .where('ownerId', isEqualTo: uid)
          .limit(200)
          .snapshots()
          .map(_waitList);

  /// "주고받았어요"를 잘못 눌렀을 때 — 대여 중 → 주고받기 예정으로 되돌리기
  static Future<void> undoHandover(String loanId) =>
      _call({'action': 'undoHandover', 'loanId': loanId});

  /// 반납 완료 — 소장자, 또는 도서관 관리자가 대신
  static Future<void> returnBook(String loanId) =>
      _call({'action': 'return', 'loanId': loanId});

  /// 빌린 사람: "반납했어요" — 소장자에게 확인 요청 (확인 전까지는 대여 중)
  static Future<void> reportReturn(String loanId) =>
      _call({'action': 'reportReturn', 'loanId': loanId});

  /// 소장자: "아직 못 받았어요" — 반납 알림을 되돌린다
  static Future<void> denyReturn(String loanId) =>
      _call({'action': 'denyReturn', 'loanId': loanId});

  /// 일정·장소 변경 — 보낸 항목만 바뀐다
  /// 수락 후: handoverDate, handoverTime, handoverPlace, returnPlace
  /// 대여 중: dueDate, returnTime, returnPlace
  static Future<void> reschedule(String loanId, Map<String, String> fields) =>
      _call({'action': 'reschedule', 'loanId': loanId, ...fields});

  static Future<void> setReturnPlace(String loanId, String place) =>
      _call({'action': 'setReturnPlace', 'loanId': loanId, 'returnPlace': place});

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }

  /// 내가 소장자이거나 빌린 사람인 대여 건 (규칙상 두 쿼리로 나눠 읽고 합친다)
  static Stream<List<Loan>> watchMine(String uid) {
    final col = FirebaseFirestore.instance.collection('loans');
    final asOwner = col.where('ownerId', isEqualTo: uid).limit(200).snapshots();
    final asBorrower =
        col.where('borrowerId', isEqualTo: uid).limit(200).snapshots();

    late final StreamController<List<Loan>> ctrl;
    List<Loan>? owned, borrowed;
    StreamSubscription<dynamic>? s1, s2;

    void emit() {
      if (owned == null || borrowed == null) return;
      final all = [...owned!, ...borrowed!];
      all.sort((a, b) {
        final at = a.updatedAt ?? a.requestedAt, bt = b.updatedAt ?? b.requestedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return bt.compareTo(at);
      });
      ctrl.add(all);
    }

    ctrl = StreamController<List<Loan>>(
      onListen: () {
        s1 = asOwner.listen((s) {
          owned = s.docs.map(Loan.fromDoc).toList();
          emit();
        }, onError: ctrl.addError);
        s2 = asBorrower.listen((s) {
          borrowed = s.docs.map(Loan.fromDoc).toList();
          emit();
        }, onError: ctrl.addError);
      },
      onCancel: () async {
        await s1?.cancel();
        await s2?.cancel();
      },
    );
    return ctrl.stream;
  }

  /// 내 알림함 (최근 50개, 클라이언트에서 최신순 정렬)
  static Stream<List<LibraryNotice>> watchNotices(String uid) {
    return FirebaseFirestore.instance
        .collection('library_notifications')
        .where('userId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((s) {
      final list = s.docs.map(LibraryNotice.fromDoc).toList();
      list.sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return -1;
        if (bt == null) return 1;
        return bt.compareTo(at);
      });
      return list;
    });
  }

  static Future<void> markAllRead(Iterable<LibraryNotice> notices) async {
    final unread = notices.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(
        FirebaseFirestore.instance.collection('library_notifications').doc(n.id),
        {'read': true},
      );
    }
    await batch.commit();
  }
}
