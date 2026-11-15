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
- 책 정보: 카카오(`lookupBook`, 시크릿 `KAKAO_REST_KEY`) → Google Books(`isbn:` 실패 시 숫자만 재검색) → 독일 국립도서관 DNB, 없으면 lobid(hbz 도서관 연합 — Kazé 등 스위스 ISBN 만화는 DNB 에 없고 여기 있음) (`lookupBook` 에 `source: dnb`, 키 없음, 표지는 MVB) → Open Library (2026-10-24, 독일어 만화 인식용)
- 잡지형 책(LTB 등 ISBN 없는 가판대 바코드 419·414·977): 스캐너가 옆의 호수 바코드까지 읽어 `4193889712990-04` 형태로 isbn 칸에 저장. 바깥 검색 없이 우리 도서관 books(isbn 같은 책)에서 찾음 — 처음 한 번은 직접 입력. ISBN 도 바깥에서 못 찾으면 우리 도서관에서 찾음 (2026-10-25)
- 대여: `loanAction` 신청(장소·메모) → 수락(전달·반납 장소) → 주고받았어요 → 돌려받았어요, 거절·취소,
  일정·장소 변경(`reschedule`), 토요일 18시 리마인드(`libraryWeeklyReminder`)
- 알림함 `library_notifications` + FCM 웹 푸시 (VAPID 키 설정됨, 로그아웃 시 토큰 삭제)
- 겨자씨: 마이페이지 "소망 도서관" 바로가기, 교인 계정 진입 차단
- 신청 가능 권수: 기본 3권 + 공개한 책(대여 쉼 제외) 3권마다 +1권, 최대 10권, 관리자 무제한 — 서버 `loanAction` request 에서 강제(`LOAN_LIMIT_*`). 연체 페널티: 연체 중 신청 불가 + 늦게 반납한 일수만큼(최대 28일, `LOAN_PENALTY_MAX_DAYS`) 신청 정지, 관리자 제외, 앱은 `LoanQuota`(`models/loan.dart`)·`QuotaCard`(내 정보). 값 바꾸면 양쪽 모두 수정
- 서가 필터: 대여 가능만·친구 책만·소장자 고르기(이름 검색 시트) — 모두 클라이언트에서 거름 (`shelf_tab.dart`)
- 서가 보기 방식: 표지 작게(기본)·보통·크게·목록 (`ShelfView`, 앱을 다시 열면 기본값)
- 표지 바꾸기 (`books/cover_picker.dart`, 등록·수정 화면에서 표지 누르기): 사진 찍기·앨범 → 600px·품질 80 으로 줄여 함수 `uploadBookCover`(base64, 800KB 이하, JPEG/PNG/WebP 확인) 가 Storage `library_covers/{uid}/` 에 저장·공개 주소 반환 — Storage 규칙은 콘솔 관리라 건드리지 않으려고 함수(admin)로 올림 / 인터넷에서 찾기(구글 이미지 새 탭 → 표지 붙여넣기 대화상자: 복사한 이미지는 `web/clipboard_image.js` 가 클립보드에서 꺼내 600px JPEG 로 줄여 업로드, 이미지 주소도 가능, imgres?imgurl= 주소도 풀어 줌) / ISBN 으로 다시 찾기(`lookupBook` source `cover` — MVB·Open Library 를 함수가 실제 그림인지 확인) / 지우기
- 시리즈 묶어 보기 (서가 보기 메뉴, 기본 켬): 제목 끝 권 번호(`Book.seriesName`/`volume`/`seriesKey` — '… 1', '… 3권', 'Band 4', '(2)')가 같은 책이 2권 이상이면 한 칸(표지 겹침 + N권 배지)으로. 누르면 `_SeriesScreen`(권 순서, 여러 소장자 섞임). 필터·검색은 묶기 전에 적용. 서버·규칙 변경 없음 (2026-10-25)
- 도움말 화면 (`help_screen.dart`) — 서가 앱바 `?` 와 내 정보 탭에서 열림
- 교인 이름 수정 — 본인(내 정보 연필)·관리자(`admin/members_screen.dart`). 함수 `renameLibraryUser` 는 users.name 만 바꾸고, 트리거 `syncLibraryUserName` 이 복사본(books·loans·library_friendships)을 맞춤(겨자씨·콘솔에서 바꿔도 동작). `syncLibraryNames`(교인 이름 수정 화면의 동기화 버튼)는 이미 어긋난 기록을 일괄 보정. 이름 수정은 교인(role member)만, 청소년부 이름은 겨자씨에서
- 알림함에서 친구 신청 바로 수락·거절 (`loans/notifications_screen.dart`) — 알림에 `type`/`fromId` 추가(서버 notifyLibrary·friendAction). 옛 알림은 fromId가 없어 본문 앞 이름으로 찾음 → functions 배포 없이도 동작, 배포하면 새 알림부터 uid로 정확히 매칭
- 책 정보 보기 (`books/book_info_sheet.dart`, 책 상세의 버튼) — 같은 시트 안에서 화면만 전환(모달 겹침 없음, 상단 바를 내리면 한 번에 닫힘, '돌아가기' 버튼) — 출판사·출간일·쪽수·정가·책 소개. 카카오(`lookupBook`, contents/date/price 필드 추가)+Google Books 합침. functions 배포 전에도 Google Books 만으로 동작(정가·카카오 소개는 배포 후). 못 찾으면 '알라딘에서 더 보기' 링크
- 대기 신청 — 이미 신청·대여 중인 책에 "대기 신청"(loanAction `wait`/`unwait`, 컬렉션 `library_waitlist` 문서ID=bookId_userId, 최대 10권). 책이 available 로 바뀌면 트리거 `notifyLibraryWaitlist`(books 업데이트)가 대기자 전원에게 알림, 먼저 신청한 사람이 빌림(request 시 본인 대기 문서 삭제). 규칙: 본인·소장자 읽기, 쓰기 금지. UI: 책 상세 버튼 / 대여 탭 "기다리는 책" / 내 책 대여 현황에 대기자 표시. 배포: rules + functions(loanAction, notifyLibraryWaitlist) + hosting
- 주고받기 되돌리기 — loanAction `undoHandover`(lent→accepted, 둘 다 가능, 반납일 삭제·책 reserved), 대여 탭 빌린 책/빌려준 책 카드에 버튼. 배포: functions:loanAction + hosting
- 반납 확인 (2026-11-13) — 소장자가 "돌려받았어요"를 잊어 계속 대여 중으로 남는 문제 대책. ① 빌린 사람 "반납했어요"(loanAction `reportReturn` → loans.`returnReportedAt`, 상태는 lent 그대로) → 소장자 카드에 "돌려받았어요 / 아직 못 받았어요(`denyReturn`)". 연체·페널티는 returnReportedAt 날짜 기준(서버 request + 앱 `LoanQuota.penaltyFor`·`Loan.isOverdue`) ② 토요일 알림(`libraryWeeklyReminder`): 반납일 지난 건은 소장자에게도 독촉, 반납 알림 후 확인 없는 건은 소장자 재알림 + 관리자에게 확인 요청(`return_check`), `RETURN_AUTO_DAYS`(7일) 지나면 자동 반납 완료(`autoReturned`, endedBy 'auto') ③ 관리자가 전체 대여 현황에서 대여 중인 건을 눌러 대신 반납 완료(loanAction `return` 을 스태프·담당자에게 허용, `returnedByAdmin`). 규칙 변경 없음. 배포: functions(loanAction, libraryWeeklyReminder) → hosting
- 책 기증 (2026-11-15) — 내 책 상세 "기증하기"로 `books.giveaway` 를 켜면 서가에 선물 배지("기증 책만" 필터). 다른 사람이 "기증 신청"하면 대여와 같은 절차(loans.`gift: true`: 신청 → 수락 → 주일에 주고받기)로 가고, "주고받았어요"(loanAction handover)에서 대여 중이 되는 대신 loans.status `given` + 책 소유권 이전(ownerId·ownerName, `donatedById/Name/At` 기록, 책은 `hidden` 으로 시작). 신청 전에는 소장자가 "기증 취소" 가능. 주고받은 뒤 되돌리기는 도서관 관리자만(책 상세 "기증 되돌리기", 함수 `donateBook` revert). 기증 신청도 신청 권수·연체 제한은 대여와 같이 적용. 규칙: books 의 donated* 클라이언트 쓰기 금지, giveaway 는 bool(테스트 추가). 배포: rules → functions(loanAction, donateBook) → hosting. **아직 배포·실기기 확인 전**
- 희망 도서 (2026-11-15) — 서가에 없는 책을 올려 두는 목록(`library_wishes`). 올리기(책 검색 또는 직접 입력, 한마디) / "저도 읽고 싶어요" 공감(읽고 싶은 사람 많은 순 정렬) / "저 있어요" → 책 등록 화면이 미리 채워지고 저장하면 희망·공감한 사람에게 알림(`wish_fulfilled`) / 들어온 책은 30일 동안 "최근에 들어온 책"에 남음. 쓰기는 전부 함수 `wishAction`(create·delete·vote·unvote·fulfill), 규칙은 읽기만 허용. 같은 ISBN 희망은 합치고, 이미 서가에 있는 ISBN 은 거절, 한 사람 10권. 이름 변경 동기화(`syncLibraryUserName`)에 희망 도서 포함. 화면 `wishes/`, 진입은 서가의 "희망 도서" 버튼·검색 결과 없을 때. 배포: rules → functions(wishAction, syncLibraryUserName) → hosting. **아직 배포·실기기 확인 전**
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
- 희망 도서 확장: 이미 등록해 둔 내 책을 희망 도서에 연결하기 / 누가 책을 등록하면 ISBN 이 같은 희망을 자동으로 완료 / 새 희망 도서가 올라오면 알림 / 오래된 '들어온 책' 문서 정리
- 대여 서재 "비치" 흐름 (소장자가 서재에 두면 → 빌릴 사람이 가져가며 확인)
- (완료 2026-10-25) 표지 직접 올리기 — 아래 '표지 바꾸기' 참고. 바꾸거나 책 삭제 시 옛 사진 파일 정리는 아직 안 함
- 내 대여 기록·통계, 인기 책, 새로 들어온 책
- 관리자 화면 확장: 반납 지난 건 독촉 알림 보내기
- 독일어 UI (2세·독일 교인)

## 주의
- 이 환경에서는 Flutter 실행 불가 → 코드 수정 후 사용자가 `flutter analyze lib` / `flutter build web` 로 확인
- `flutter build web` 실패 시 먼저 `flutter clean` (패키지 제거 후 찌꺼기 문제 있었음)
- 규칙 배포 전 `firebase deploy --only firestore:rules --dry-run`
