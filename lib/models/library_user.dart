import 'package:cloud_firestore/cloud_firestore.dart';

/// 도서관에서 쓰는 사용자 정보 (users/{uid} 문서 — 겨자씨와 공유)
///
/// - role 'member'  : 일반 교인. library.approved 가 true 여야 도서관 사용
/// - 그 외 role     : 청소년부(학생·교사 등). 바로 사용
/// - library.isLibrarian : 도서관 담당자 (가입 승인·초대 링크)
class LibraryUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool approved;
  final bool isLibrarian;

  const LibraryUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.approved,
    required this.isLibrarian,
  });

  /// Firestore 규칙의 isStaff() 와 같은 목록
  static const Set<String> staffRoles = {
    'teacher', 'jeondosa', 'jipsa',
    'adminStudent', 'adminTeacher', 'master', 'admin',
  };

  bool get isMember => role == 'member';
  bool get isYouth => !isMember;
  bool get canUseLibrary => isYouth || approved;
  bool get isStaff => staffRoles.contains(role);
  bool get isLibraryAdmin => isStaff || isLibrarian;

  String get groupLabel => isMember ? '교인' : '청소년부';

  factory LibraryUser.fromMap(String uid, Map<String, dynamic> data) {
    final rawLibrary = data['library'];
    final lib = rawLibrary is Map ? rawLibrary : const {};
    return LibraryUser(
      uid: uid,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      // role 이 없으면 겨자씨 앱·규칙과 같이 visitor 로 본다
      role: data['role']?.toString() ?? 'visitor',
      approved: lib['approved'] == true,
      isLibrarian: lib['isLibrarian'] == true,
    );
  }

  factory LibraryUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      LibraryUser.fromMap(doc.id, doc.data() ?? const {});
}
