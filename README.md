# 소망 도서관

베를린 소망교회 교인들이 집에 있는 책을 등록하고, 주일에 서로 빌려주는 웹앱.

- 계정은 겨자씨 앱과 같다 (같은 이메일·비밀번호 / Google)
- 청소년부가 아닌 교인은 초대 링크로 가입하거나, 가입 후 담당자 승인을 받는다

개발 규칙과 구조는 `CLAUDE.md`, 설계 결정은 겨자씨 저장소 `doc/LIBRARY_PLAN.md` 참고.

## 처음 설정 (한 번만)
1. `firebase hosting:sites:create somang-library`
2. Firebase 콘솔 → Authentication → 설정 → 승인된 도메인에 `somang-library.web.app` 추가
3. Firebase 콘솔 → Authentication → 로그인 방법 → Google 사용 설정
4. 겨자씨 저장소에서 규칙·함수 배포 (`feature/church-member-auth`)
