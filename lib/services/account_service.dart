import 'package:cloud_functions/cloud_functions.dart';

/// 교인 계정 — 이름 수정은 Cloud Function renameLibraryUser (mustardseed, europe-west1)
/// 이름은 책·대여·친구 기록에도 복사돼 있어서 함수가 한꺼번에 바꾼다.
class AccountService {
  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// [uid] 가 없으면 내 이름, 있으면 그 교인의 이름 (도서관 관리자만)
  static Future<void> rename(String name, {String? uid}) => _fn
      .httpsCallable('renameLibraryUser')
      .call({'name': name, 'uid': ?uid});

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }
}
