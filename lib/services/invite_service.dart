import 'package:cloud_functions/cloud_functions.dart';

/// 교인 초대 링크 — Cloud Functions(mustardseed 저장소, europe-west1) 호출
class InviteService {
  /// 초대 링크(?invite=CODE)로 들어왔을 때의 코드
  static String? pendingCode;

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static void captureFromUrl() {
    final raw = Uri.base.queryParameters['invite'];
    if (raw == null) return;
    final code = normalize(raw);
    if (code.isNotEmpty) pendingCode = code;
  }

  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// 초대 링크 주소 (지금 열려 있는 도서관 주소 기준)
  static String linkFor(String code) => '${Uri.base.origin}/?invite=$code';

  /// 초대 코드 사용 → 'created' | 'approved' | 'already' | 'youth'
  static Future<String> redeem(String code, {String? name}) async {
    final result = await _functions.httpsCallable('redeemInvite').call({
      'code': normalize(code),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    pendingCode = null;
    return data['status']?.toString() ?? '';
  }

  /// 초대 링크 만들기 (도서관 관리자)
  static Future<({String code, DateTime expiresAt})> create({
    int maxUses = 30,
    int days = 14,
    String memo = '',
  }) async {
    final result = await _functions.httpsCallable('createLibraryInvite').call({
      'maxUses': maxUses,
      'days': days,
      'memo': memo,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      code: data['code'].toString(),
      expiresAt: DateTime.parse(data['expiresAt'].toString()).toLocal(),
    );
  }

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      // 함수가 보낸 한국어 메시지를 그대로 보여준다
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }
}
