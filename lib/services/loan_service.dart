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

  static Future<void> returnBook(String loanId) =>
      _call({'action': 'return', 'loanId': loanId});

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
