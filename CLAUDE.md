# 소망 도서관 (Somang Library) - Claude Code Rules

## 프로젝트 개요
- **앱:** 소망 도서관 — 베를린 소망교회 교인들이 개인 책을 등록·대여하는 웹앱(PWA)
- **프레임워크:** Flutter Web (Dart) + Firebase
- **Firebase 프로젝트:** `mustard-seed-6b9e7` — **겨자씨(mustardseed) 앱과 공유** (Auth + `users`)
- **Hosting 사이트:** `somang-library` → https://somang-library.web.app
- **겨자씨 저장소:** `E:\Coding\mustardseed` — 설계 원본 `doc/LIBRARY_PLAN.md`

## ⚠️ 절대 규칙
- **Firestore 규칙과 Cloud Functions 는 이 저장소에서 배포하지 않는다.**
  `firebase.json` 에는 hosting 만 있다. 규칙 배포는 전체를 덮어쓰므로 겨자씨 규칙이 사라진다.
  도서관 컬렉션 규칙·함수는 **mustardseed 저장소**의 `firestore.rules` / `functions/index.js` 에 추가한다.
- 배포는 `firebase deploy --only hosting` 만.
- `lib/firebase_options.dart` 는 겨자씨 웹 앱 설정을 그대로 쓴다 (수정 금지).

## 계정·권한
| 구분 | 조건 | 도서관 |
|---|---|---|
| 청소년부 | `role` ≠ `member` | 바로 사용 |
| 교인 | `role == 'member'` | `library.approved == true` 일 때 |
| 도서관 관리자 | 스태프 역할 또는 `library.isLibrarian` | 초대 링크·가입 승인 |

- 교인은 청소년부 `users` 문서(학생 개인정보)를 **읽을 수 없다** → 화면에 필요한 이름은 `books`/`loans` 에 복사해 둔다.
- 초대: `createLibraryInvite` / `redeemInvite` (callable, `europe-west1`)
- 초대 링크 형식: `https://somang-library.web.app/?invite=CODE`

## 책 (books)
- 필드: ownerId, ownerName(복사), title, author, publisher, isbn, coverUrl, note, status, createdAt, updatedAt
- 문자열 필드는 null 금지(빈 문자열) — 규칙 `isValidBook`
- status: `available`·`hidden` 은 소장자가, `requested`·`lent` 는 대여 함수가 바꾼다 (진행 중엔 소장자 수정·삭제 불가)
- 책 정보 검색: `BookLookupService` (카카오 lookupBook 함수 → Google Books → DNB(lookupBook `source: dnb`) → Open Library)
- 바코드: `web/scanner.js` (zxing-wasm, `web/zxing` 자체 호스팅) — Dart 는 `PhotoBarcode`
  - 실시간 `somangScanLive()`: 후면 메인 카메라(`camera2 0`) 선택 + 연속 자동초점 + 1080p, 가운데 띠를 잘라 인식
  - 사진 `somangReadBarcodes(blob)`: `image_picker` 로 찍은 사진
  - 브라우저 내장 BarcodeDetector·mobile_scanner 는 갤럭시에서 인식 실패해서 쓰지 않는다
- 표지 이미지: `BookCover` — `cacheWidth` + `WebHtmlElementStrategy.fallback`(CORS 없는 표지 서버 대응)

## 대여 (loans)
- 상태 변경은 전부 Cloud Function `loanAction` (mustardseed, europe-west1): request → accept(장소 확정) → handover → return, reject·cancel·setReturnPlace
- 반납 확인: 빌린 사람 `reportReturn`("반납했어요", `returnReportedAt` 기록·상태는 lent) → 소장자 `return` 또는 `denyReturn`. 확인이 없으면 토요일 알림이 관리자에게 알리고 7일 뒤 자동 완료. 관리자는 전체 대여 현황에서 `return` 을 대신 할 수 있다
- 장소 선택지: `LoanPlaces.presets` (게마인데잘 / 대여 서재 / 대예배실 앞) + 직접 입력
- 날짜는 'YYYY-MM-DD' 주일 문자열 (handoverDate, dueDate=4주 뒤 주일)
- 대여 목록·알림함 구독은 `HomeShell` 한 곳에서 (탭 배지 공용)
- 알림함 `library_notifications`, 웹 푸시 토큰 `users/{uid}/libraryTokens/{token}`
- 웹 푸시: `PushService.vapidKey` (콘솔 웹 푸시 인증서 공개 키) 필요, `web/firebase-messaging-sw.js`
  로그아웃 시 토큰 삭제 (`AuthService.signOut` → `PushService.forget`)

## 책 기증 (대여와 같은 절차로 소유권 이전)
- 내 책 상세의 "기증하기" → `books.giveaway: true` (소장자가 직접 켜고 끔, `BookService.setGiveaway`). 서가에 선물 배지·"기증 책만" 필터
- 기증 책을 신청하면 `loanAction` 이 `loans.gift: true` 로 만든다 → 수락 → 주일에 주고받기. **handover 에서 대여 중(lent)이 되는 대신 `loans.status = 'given'`**, `books.ownerId`·`ownerName` 이 받은 사람으로 바뀌고 `donatedById`·`donatedByName`·`donatedAt` 기록, 책은 `hidden`(대여 쉼)으로 시작
- 소유자와 donated* 필드는 규칙상 클라이언트가 못 쓴다 (함수 전용). `giveaway` 는 bool 만
- 되돌리기는 도서관 관리자만 (책 상세의 "기증 되돌리기", 함수 `donateBook` action `revert`) — 기증한 사람에게 돌아간다
- 화면 문구는 `Loan.gift`·`Book.giveaway` 로 분기 (`loans_tab.dart`, `place_picker.dart`, `book_detail_sheet.dart`)

## 희망 도서 (library_wishes)
- 서가에 없는 책을 "읽고 싶어요"로 올려 두는 목록. 읽기는 도서관 사용자 전원, **쓰기는 전부 Cloud Function `wishAction`** (mustardseed, europe-west1): create · delete · vote/unvote("저도 읽고 싶어요") · fulfill("저 있어요")
- "저 있어요" → `BookFormScreen(forWish:)` 로 책 등록 → `WishService.fulfill(wishId, bookId)` → 희망한 사람·공감한 사람에게 알림(`wish_fulfilled`)
- 같은 ISBN 의 희망이 이미 있으면 새로 만들지 않고 공감만 더한다. 이미 서가에 있는 ISBN 은 거절. 한 사람 10권(`WISH_MAX_OPEN` = `WishService.maxOpen`)
- 화면: `wishes/wishes_screen.dart`(목록) · `wishes/wish_form_screen.dart`(올리기). 진입: 서가의 "희망 도서" 버튼 / 서가 검색 결과가 없을 때 버튼

## 화면 흐름
`AuthGate` → 로그인 안 함: `LoginScreen` / users 문서 없음: `JoinScreen` / 미승인 교인: `PendingScreen` / 그 외: `HomeShell`
로그인·가입 후 화면 이동은 AuthGate 가 스트림으로 처리한다 (각 화면에서 Navigator 로 넘기지 않음).

## 코딩 규칙 (겨자씨와 동일)
- 한국어 주석, 파일 snake_case, 클래스 PascalCase
- Firestore: `where + orderBy` 조합 금지(정렬은 클라이언트), 목록 쿼리 `.limit()` 필수
- `snapshots()` 스트림은 `build()` 가 아니라 State 필드(initState/late final)에 보관
- 이미지 업로드는 압축 후, 네트워크 이미지는 `cacheWidth` 지정 (iOS Safari 메모리)
- **아이폰 강제 종료 대책 (2026-10-10 확정)**: 원인은 CanvasKit 이 이미지를 WebGL 텍스처로 올리는 경로의
  GPU 메모리 (flutter/flutter#152709). 실험 결과 CPU 렌더링만 살아남음. 메모리 적은 3x 기기(미니 4GB)만 죽고
  2x(SE)·고사양 기종은 멀쩡 → `web/index.html` 이 (A) iPhone 미니 크기(375×812@3x)는 처음부터 `canvasKitForceCpuOnly`,
  (B) 그 외 iOS 는 WebGL 로 시작하되 30분 안에 2번 연속 비정상 종료(localStorage `gpu_alive` 표시가 안 지워짐)면
  CPU 로 자동 전환해 저장(`engine_auto`). CPU 렌더링 중인 3x 기기는 `main.dart` 가 배율을 2x 로 낮춘다
  (`WebPlatform.dprOverride`, 1x 최저사양 선택 가능). 실제 적용된 모드는 `engine_effective` 키로 Dart 에 전달.
  도움말 '실험' 카드(`help_screen.dart`)에서 렌더링·해상도를 바꿀 수 있고 localStorage 에 저장된다
- **iOS(WebKit) 에서는 네트워크 이미지를 `<img>` 로 그린다** — `WebPlatform.isIosWebKit` 이면
  `webHtmlElementStrategy: WebHtmlElementStrategy.prefer`, 그 외는 `fallback` (`BookCover` 참고).
  CanvasKit 의 이미지 → WebGL 텍스처 경로가 Safari 탭 메모리 상한을 넘겨 페이지가 강제 종료된다
  (flutter/flutter#152709). 새로 `Image.network` 를 쓰는 곳도 같은 분기를 넣을 것
- 본문은 `PageFrame` (가운데 maxWidth 560)

## 인수인계
새 세션은 `doc/HANDOFF.md` 부터 읽는다 (진행 상황·남은 일·다음 기능 후보).

## 실행 / 배포
```powershell
flutter pub get
flutter run -d chrome          # 로컬 (localhost 는 Auth 승인 도메인에 기본 포함)
flutter test
flutter build web --release
firebase deploy --only hosting
```
