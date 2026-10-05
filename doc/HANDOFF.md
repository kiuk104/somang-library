# 소망 도서관 — 작업 인수인계 (새 세션은 이 파일부터)

> 마지막 갱신: 2026-10-05 · 규칙·구조는 `CLAUDE.md`, 설계 원본은 `E:\Coding\mustardseed\doc\LIBRARY_PLAN.md`

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

## 확인 필요 / 남은 일
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
- 도서관 관리자 화면: 전체 대여 현황, 반납 지난 건
- 독일어 UI (2세·독일 교인)

## 주의
- 이 환경에서는 Flutter 실행 불가 → 코드 수정 후 사용자가 `flutter analyze lib` / `flutter build web` 로 확인
- `flutter build web` 실패 시 먼저 `flutter clean` (패키지 제거 후 찌꺼기 문제 있었음)
- 규칙 배포 전 `firebase deploy --only firestore:rules --dry-run`
