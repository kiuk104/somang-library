import 'package:cloud_firestore/cloud_firestore.dart';

/// 나와 상대의 관계
enum FriendRelation { none, friend, sentRequest, receivedRequest }

/// library_friendships/{두 uid 를 정렬해 '_' 로 이은 값}
/// 필드: users[두 uid], requesterId, status(pending|accepted), names{uid: 이름}
/// 쓰기는 Cloud Function friendAction 만 한다 (클라이언트는 읽기만).
class Friendship {
  final String id;
  final String otherId; // 나 말고 상대 uid
  final String otherName;
  final String status; // 'pending' | 'accepted'
  final bool iRequested; // 신청을 내가 보냈는가
  final DateTime? createdAt;

  const Friendship({
    required this.id,
    required this.otherId,
    required this.otherName,
    required this.status,
    required this.iRequested,
    this.createdAt,
  });

  bool get accepted => status == 'accepted';

  factory Friendship.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String myUid) {
    final d = doc.data() ?? const {};
    final users = d['users'] is List ? List<String>.from(d['users']) : <String>[];
    final otherId = users.firstWhere((u) => u != myUid, orElse: () => '');
    final names = d['names'] is Map ? Map<String, dynamic>.from(d['names']) : {};
    final created = d['createdAt'];
    return Friendship(
      id: doc.id,
      otherId: otherId,
      otherName: names[otherId]?.toString() ?? '',
      status: d['status']?.toString() ?? 'pending',
      iRequested: d['requesterId'] == myUid,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// 이름 검색 결과 한 명
class FriendCandidate {
  final String uid;
  final String name;
  final String hint; // 교인/청소년부 + 가린 이메일 (동명이인 구분용)
  const FriendCandidate(
      {required this.uid, required this.name, required this.hint});
}
