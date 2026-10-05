import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/friendship.dart';

/// 친구 — 읽기는 library_friendships 직접, 변경·검색은 Cloud Function
/// (friendAction / searchLibraryUsers, mustardseed 저장소, europe-west1)
class FriendService {
  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// 내가 들어 있는 친구 관계 전부 (신청 중 + 수락됨)
  static Stream<List<Friendship>> watchMine(String uid) => FirebaseFirestore
      .instance
      .collection('library_friendships')
      .where('users', arrayContains: uid)
      .limit(300)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Friendship.fromDoc(d, uid))
          .where((f) => f.otherId.isNotEmpty)
          .toList());

  static Set<String> friendIds(Iterable<Friendship> list) =>
      {for (final f in list) if (f.accepted) f.otherId};

  static FriendRelation relationTo(Iterable<Friendship> list, String otherId) {
    for (final f in list) {
      if (f.otherId != otherId) continue;
      if (f.accepted) return FriendRelation.friend;
      return f.iRequested
          ? FriendRelation.sentRequest
          : FriendRelation.receivedRequest;
    }
    return FriendRelation.none;
  }

  static Future<String> _act(String action, String uid) async {
    final res = await _fn
        .httpsCallable('friendAction')
        .call({'action': action, 'uid': uid});
    return (res.data as Map)['status']?.toString() ?? '';
  }

  /// 친구 신청 → 'requested' | 'accepted'(상대가 먼저 신청해 둔 경우 바로 친구)
  static Future<String> request(String uid) => _act('request', uid);
  static Future<void> accept(String uid) => _act('accept', uid);
  static Future<void> decline(String uid) => _act('decline', uid);
  static Future<void> cancel(String uid) => _act('cancel', uid);
  static Future<void> remove(String uid) => _act('remove', uid);

  /// 이름으로 도서관 가입자 찾기 (두 글자 이상)
  static Future<List<FriendCandidate>> search(String query) async {
    final res =
        await _fn.httpsCallable('searchLibraryUsers').call({'query': query});
    final list = (res.data as Map)['users'];
    if (list is! List) return const [];
    return [
      for (final u in list)
        FriendCandidate(
          uid: (u as Map)['uid'].toString(),
          name: u['name']?.toString() ?? '',
          hint: u['hint']?.toString() ?? '',
        ),
    ];
  }

  static String messageFor(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? '문제가 생겼어요. (${e.code})';
    }
    return '문제가 생겼어요. ($e)';
  }
}
