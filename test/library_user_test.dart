import 'package:flutter_test/flutter_test.dart';
import 'package:somang_library/models/library_user.dart';

void main() {
  LibraryUser u(Map<String, dynamic> data) => LibraryUser.fromMap('uid', data);

  test('청소년부 회원은 승인 없이 사용', () {
    expect(u({'role': 'student'}).canUseLibrary, isTrue);
    expect(u({'role': 'teacher'}).canUseLibrary, isTrue);
    expect(u({}).canUseLibrary, isTrue); // role 없음 = visitor
  });

  test('교인은 승인되어야 사용', () {
    expect(u({'role': 'member'}).canUseLibrary, isFalse);
    expect(u({'role': 'member', 'library': {'approved': false}}).canUseLibrary, isFalse);
    expect(u({'role': 'member', 'library': {'approved': true}}).canUseLibrary, isTrue);
  });

  test('관리 권한: 스태프 또는 사서', () {
    expect(u({'role': 'teacher'}).isLibraryAdmin, isTrue);
    expect(u({'role': 'student'}).isLibraryAdmin, isFalse);
    expect(u({'role': 'member', 'library': {'isLibrarian': true}}).isLibraryAdmin, isTrue);
  });
}
