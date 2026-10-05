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
- 책 정보 검색: `BookLookupService` (카카오 lookupBook 함수 → Google Books → Open Library)
- 바코드: 폰 기본 카메라 사진(`image_picker`) → `web/zxing`(zxing-wasm, 자체 호스팅) — `web/index.html` 의 `somangReadBarcodes`.
  브라우저 실시간 카메라·내장 BarcodeDetector 는 갤럭시에서 인식 실패해서 쓰지 않는다
- 표지 이미지: `BookCover` — `cacheWidth` + `WebHtmlElementStrategy.fallback`(CORS 없는 표지 서버 대응)

## 화면 흐름
`AuthGate` → 로그인 안 함: `LoginScreen` / users 문서 없음: `JoinScreen` / 미승인 교인: `PendingScreen` / 그 외: `HomeShell`
로그인·가입 후 화면 이동은 AuthGate 가 스트림으로 처리한다 (각 화면에서 Navigator 로 넘기지 않음).

## 코딩 규칙 (겨자씨와 동일)
- 한국어 주석, 파일 snake_case, 클래스 PascalCase
- Firestore: `where + orderBy` 조합 금지(정렬은 클라이언트), 목록 쿼리 `.limit()` 필수
- `snapshots()` 스트림은 `build()` 가 아니라 State 필드(initState/late final)에 보관
- 이미지 업로드는 압축 후, 네트워크 이미지는 `cacheWidth` 지정 (iOS Safari 메모리)
- 본문은 `PageFrame` (가운데 maxWidth 560)

## 실행 / 배포
```powershell
flutter pub get
flutter run -d chrome          # 로컬 (localhost 는 Auth 승인 도메인에 기본 포함)
flutter test
flutter build web --release
firebase deploy --only hosting
```
