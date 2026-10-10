# 소망 도서관 — 작업 인수인계 (새 세션은 이 파일부터)

> 마지막 갱신: 2026-10-05 (오후) · 규칙·구조는 `CLAUDE.md`, 설계 원본은 `E:\Coding\mustardseed\doc\LIBRARY_PLAN.md`

## 저장소 2개 (반드시 둘 다 연결해서 작업)
| 폴더 | 역할 | 배포 |
|---|---|---|
| `E:\Coding\somang-library` | 도서관 웹앱 (Flutter Web) | `firebase deploy --only hosting` 만 |
| `E:\Coding\mustardseed` | **Firestore 규칙 + Cloud Functions** (겨자씨와 공유), 브랜치 `feature/church-member-auth` | `--only firestore:rules`, `--only functions` |

- Firebase 프로젝트 `mustard-seed-6b9e7`, Hosting 사이트 `somang-library` → https://somang-library.web.app
- 규칙에 달란트 시장(`market_*`, `nfc_cards`) 규칙도 들어 있음 — 콘솔에서 직접 고치지 말 것

## 완료된 기능
- 계정: 겨자씨 계정 공유, 교인 `role: member` + `library.approved`, 초대 링크(`createLibraryInvite`/`redeemInvite`), 가입 승인
- 책: 등록·수정·대여 쉼·삭제, 서가(검색·대여 가능만), 표지 자동 생성
- 바코드: `web/scanner.js` (zxing-wasm 자체 호스팅) 실시간 스캔 + 사진 인식 — 갤럭시 확인 완료
- 책 정보: 카카오(`lookupBook`, 시크릿 `KAKAO_REST_KEY`) → Google Books → Open Library
- 대여: `loanAction` 신청(장소·메모) → 수락(전달·반납 장소) → 주고받았어요 → 돌려받았어요, 거절·취소,
  일정·장소 변경(`reschedule`), 토요일 18시 리마인드(`libraryWeeklyReminder`)
- 알림함 `library_notifications` + FCM 웹 푸시 (VAPID 키 설정됨, 로그아웃 시 토큰 삭제)
- 겨자씨: 마이페이지 "소망 도서관" 바로가기, 교인 계정 진입 차단
- 신청 가능 권수: 기본 3권 + 공개한 책(대여 쉼 제외) 3권마다 +1권, 최대 10권, 관리자 무제한 — 서버 `loanAction` request 에서 강제(`LOAN_LIMIT_*`). 연체 페널티: 연체 중 신청 불가 + 늦게 반납한 일수만큼(최대 28일, `LOAN_PENALTY_MAX_DAYS`) 신청 정지, 관리자 제외, 앱은 `LoanQuota`(`models/loan.dart`)·`QuotaCard`(내 정보). 값 바꾸면 양쪽 모두 수정
- 서가 필터: 대여 가능만·친구 책만·소장자 고르기(이름 검색 시트) — 모두 클라이언트에서 거름 (`shelf_tab.dart`)
- 서가 보기 방식: 표지 작게(기본)·보통·크게·목록 (`ShelfView`, 앱을 다시 열면 기본값)
- 도움말 화면 (`help_screen.dart`) — 서가 앱바 `?` 와 내 정보 탭에서 열림
- 교인 이름 수정 — 본인(내 정보 연필)·관리자(`admin/members_screen.dart`). 함수 `renameLibraryUser` 는 users.name 만 바꾸고, 트리거 `syncLibraryUserName` 이 복사본(books·loans·library_friendships)을 맞춤(겨자씨·콘솔에서 바꿔도 동작). `syncLibraryNames`(교인 이름 수정 화면의 동기화 버튼)는 이미 어긋난 기록을 일괄 보정. 이름 수정은 교인(role member)만, 청소년부 이름은 겨자씨에서
- 알림함에서 친구 신청 바로 수락·거절 (`loans/notifications_screen.dart`) — 알림에 `type`/`fromId` 추가(서버 notifyLibrary·friendAction). 옛 알림은 fromId가 없어 본문 앞 이름으로 찾음 → functions 배포 없이도 동작, 배포하면 새 알림부터 uid로 정확히 매칭
- 책 정보 보기 (`books/book_info_sheet.dart`, 책 상세의 버튼) — 앱 안 시트에 출판사·출간일·쪽수·정가·책 소개. 카카오(`lookupBook`, contents/date/price 필드 추가)+Google Books 합침. functions 배포 전에도 Google Books 만으로 동작(정가·카카오 소개는 배포 후). 못 찾으면 '알라딘에서 더 보기' 링크
- 주고받기 되돌리기 — loanAction `undoHandover`(lent→accepted, 둘 다 가능, 반납일 삭제·책 reserved), 대여 탭 빌린 책/빌려준 책 카드에 버튼. 배포: functions:loanAction + hosting
- 내 책 대여 현황 (`books/my_book_loans_screen.dart`) — 소장자용 보기 전용 화면. 책별 신청자·대여자·일정·장소·연체, 지난 기록, 요약 숫자. 진입: 내 책 탭 앱바 아이콘 / 대여 탭 맨 위 카드. loans(ownerId==나)와 books를 직접 구독, 서버·규칙 변경 없음
- 전체 대여 현황 (`admin/admin_loans_screen.dart`) — 반납 지난 건·진행 중·지난 기록, 검색. 규칙이 관리자 loans 읽기를 이미 허용해 클라이언트만 추가
- 도서관 담당자 지정 (`admin/librarian_screen.dart`, 스태프만 — 규칙이 이미 허용해서 클라이언트에서 직접 씀)
- 새 가입 대기 교인 → 담당자에게 알림·푸시 (`notifyLibraryJoinRequest`, 담당자가 없으면 스태프)
- 도서관 알림은 겨자씨 회원(role ≠ member)에게 겨자씨 쪽지(`messages`, fromId `system`)로도 발송 (`notifyLibrary`)
- 친구: 신청→수락 (`library_friendships`, 함수 `friendAction`·`searchLibraryUsers`), 화면 `friends/friends_screen.dart`,
  책 상세에서 소장자에게 친구 신청. 책 `visibility`('public'|'friends') — 등록·수정 화면의 "친구에게만 공개"
  - 서가에서 숨기기는 앱(클라이언트)이 친구 목록으로 거른다. 신청은 `loanAction` 이 서버에서 친구 여부를 확인한다.
  - 한계: 규칙 수준의 열람 차단은 아님 (API 로 직접 읽으면 목록은 보임). 필요하면 books 읽기 규칙 + 기존 책 visibility 채우기 마이그레이션이 필요.

## 확인 필요 / 남은 일
- [ ] 2026-10-05 변경 배포: 규칙(`--dry-run` 먼저, 테스트 `npm test`) → 함수(notifyLibraryJoinRequest·friendAction·searchLibraryUsers·loanAction·libraryWeeklyReminder) → hosting. 함수·규칙은 mustardseed `feature/church-member-auth` 브랜치에서
- [ ] 대여·알림·일정 변경 배포 후 실제 기기 테스트 (규칙 → 함수 → hosting 순)
- [ ] 카카오 키 설정·`lookupBook` 동작 확인 (한글 저자로 나오는지)
- [ ] 아이폰: 홈 화면 추가 후 푸시 수신 확인
- [ ] GitHub: `somang-library` 저장소 만들고 push / 겨자씨 브랜치 push + PR
- [ ] 겨자씨 `firebase.json` 폰트 7일 캐시 → 새 아이콘이 빈칸으로 보이는 문제 (MaterialIcons 캐시 줄이기)
- [ ] 겨자씨 회원가입이 기본 `student` — 아무나 청소년부로 가입 가능 (팀 결정 필요: visitor 승인제?)

## 다음 기능 후보
- 대여 서재 "비치" 흐름 (소장자가 서재에 두면 → 빌릴 사람이 가져가며 확인)
- 책 사진 직접 업로드 (표지 없는 책) — Storage 규칙 필요
- 내 대여 기록·통계, 인기 책, 새로 들어온 책
- 관리자 화면 확장: 반납 지난 건 독촉 알림 보내기
- 독일어 UI (2세·독일 교인)

## 주의
- 이 환경에서는 Flutter 실행 불가 → 코드 수정 후 사용자가 `flutter analyze lib` / `flutter build web` 로 확인
- `flutter build web` 실패 시 먼저 `flutter clean` (패키지 제거 후 찌꺼기 문제 있었음)
- 규칙 배포 전 `firebase deploy --only firestore:rules --dry-run`
