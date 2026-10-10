import 'package:flutter/material.dart';

import '../models/library_user.dart';
import '../widgets/page_frame.dart';
import '../utils/web_platform.dart';
import '../widgets/version_badge.dart';

/// 도움말 — 처음 쓰는 교인을 위한 사용법 (항목을 눌러 펼쳐 본다)
class HelpScreen extends StatelessWidget {
  final LibraryUser me;
  const HelpScreen({super.key, required this.me});

  /// 어느 화면에서든 도움말 열기
  static void open(BuildContext context, LibraryUser me) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HelpScreen(me: me)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <_Section>[
      const _Section(
        icon: Icons.local_library_outlined,
        title: '서가에서 책 찾기',
        lines: [
          '"서가" 탭에는 교인들이 등록한 모든 책이 모여 있어요.',
          '위 검색창에 제목·저자·소장자 이름을 넣으면 찾아 줘요.',
          '"대여 가능만"을 켜면 지금 빌릴 수 있는 책만, "친구 책만"을 켜면 친구가 가진 책만 보여요.',
          '"소장자"를 누르면 특정 교인이 가진 책만 모아 볼 수 있어요. 이름으로 찾을 수도 있어요.',
          '권수 옆 "보기 방식" 메뉴에서 표지 크기(작게·보통·크게)나 목록으로 바꿀 수 있어요.',
          '지금 빌릴 수 없는 책은 흐리게 보이고 표지에 상태 표시가 붙어요. 노랑은 "신청 중", 파랑은 "전달 예정"(수락됨), 진한 빨강은 "대여 중", 회색은 소장자가 잠시 쉬는 "대여 쉼"이에요.',
        ],
      ),
      const _Section(
        icon: Icons.auto_stories_outlined,
        title: '내 책 등록하기',
        lines: [
          '"내 책" 탭에서 새 책을 등록해요.',
          '책 뒷면 바코드(ISBN)를 카메라로 비추거나 사진으로 찍으면 제목·저자·표지가 자동으로 채워져요.',
          '바코드가 안 읽히면 제목으로 검색하거나 직접 입력하세요.',
          '표지가 없는 책은 제목으로 만든 표지가 대신 보여요.',
          '잠시 빌려주기 어려우면 "대여 쉼"으로 바꿔 두세요. 서가에는 보이지만 신청은 받지 않아요.',
          '대여가 진행 중인 책은 수정하거나 지울 수 없어요.',
          '"내 책" 탭 오른쪽 위의 대여 현황 아이콘(또는 "대여" 탭 맨 위 카드)을 누르면 내 책마다 누가 신청했는지, 누가 빌려 갔고 언제 돌아오는지, 지난 대여 기록까지 볼 수 있어요.',
          '책을 등록·수정할 때 "친구에게만 공개"를 켜면 서로 친구인 사람만 그 책을 보고 신청할 수 있어요. 내 책 목록에는 "친구 공개"로 표시돼요.',
        ],
      ),
      const _Section(
        icon: Icons.people_outline,
        title: '친구 만들기',
        lines: [
          '"내 정보 → 친구"에서 이름으로 찾아 친구 신청을 보낼 수 있어요.',
          '서가에서 책을 눌렀을 때 소장자 이름 아래의 "친구 신청" 버튼으로도 바로 신청할 수 있어요.',
          '상대가 수락하면 서로 친구가 돼요. 신청이 오면 알림이 가고, 알림함에서 바로 수락·거절하거나 "내 정보 → 친구"에서 해도 돼요.',
          '친구를 끊으면 서로의 "친구에게만 공개" 책이 다시 보이지 않아요.',
        ],
      ),
      const _Section(
        icon: Icons.swap_horiz_rounded,
        title: '책 빌리기 · 빌려주기',
        lines: [
          '1. 빌릴 사람이 책을 눌러 "대여 신청"을 해요. 받고 싶은 장소와 메모를 남길 수 있어요.',
          '2. 소장자가 수락하면서 주고받을 장소와 반납할 장소를 정해요. 거절할 수도 있어요.',
          '3. 주일에 만나 책을 건네면 둘 중 누구든 "주고받았어요"를 눌러요. 이때부터 대여 중이에요.',
          '4. 반납일은 기본 4주 뒤 주일이에요. 책을 돌려받은 소장자가 "돌려받았어요"를 누르면 끝나고, 책은 다시 서가에 올라가요.',
          '한 번에 신청·대여할 수 있는 책은 기본 3권까지예요. 내 책을 공개할수록 늘어나요 — 공개한 책(대여 쉼 제외) 3권마다 1권씩, 최대 10권. 도서관 관리자는 제한이 없어요. 지금 몇 권 썼는지는 "내 정보"에서 볼 수 있어요.',
          '반납일이 지난 책이 있으면 새로 신청할 수 없어요. 늦게 반납했다면 늦은 일수만큼(최대 4주) 새 신청이 정지돼요. 도서관 관리자는 해당되지 않아요.',
          '신청·수락 뒤에도 날짜·시간·장소를 바꾸고 싶으면 대여 화면에서 일정 변경을 하세요. 상대방에게 알림이 가요.',
          '신청 중이거나 수락된 대여는 두 사람 모두 취소할 수 있어요.',
          '"주고받았어요"를 잘못 눌렀다면 대여 화면의 "되돌리기"(또는 "아직 못 받았어요")로 주고받기 예정 상태로 돌릴 수 있어요. 상대방에게도 알림이 가요.',
          '주일 오후 2시 이후에 수락하면 전달은 다음 주일로 잡혀요.',
        ],
      ),
      const _Section(
        icon: Icons.notifications_active_outlined,
        title: '알림 받기',
        lines: [
          '"내 정보"의 "알림 켜기"를 누르면 신청·수락·반납일을 푸시로 받아요.',
          '대여 탭 위쪽 종 모양에서 지난 알림을 볼 수 있어요.',
          '매주 토요일 저녁 6시에 다음 날 주고받을 책과 반납할 책을 알려 줘요.',
          '아이폰은 Safari에서 "홈 화면에 추가"를 한 뒤 그 앱으로 열어야 푸시가 와요.',
        ],
      ),
      const _Section(
        icon: Icons.person_add_alt_outlined,
        title: '가입과 승인',
        lines: [
          '초대 링크로 들어오면 승인 없이 바로 쓸 수 있어요.',
          '링크 없이 가입했다면 도서관 담당자가 승인할 때까지 기다려야 해요. 빨리 쓰려면 담당자에게 초대 코드를 받아 입력하세요.',
          '청소년부 계정은 따로 승인 없이 쓸 수 있어요.',
          '교인 계정은 "내 정보" 카드의 연필 버튼으로 이름을 고칠 수 있어요. 책·대여 기록에 보이는 이름도 함께 바뀌어요.',
        ],
      ),
      if (me.isLibraryAdmin)
        _Section(
          icon: Icons.admin_panel_settings_outlined,
          title: '담당자 안내',
          lines: [
            '"내 정보 → 도서관 관리"에서 교인 초대 링크를 만들고 가입을 승인해요.',
            '"교인 이름 수정"에서 잘못 입력한 교인의 이름을 고칠 수 있어요. 이름을 고치면 이미 올린 책과 대여 기록의 이름도 몇 초 안에 따라 바뀌고, 위쪽 동기화 버튼으로 어긋난 이전 기록을 한꺼번에 맞출 수도 있어요.',
            '"전체 대여 현황"에서 진행 중인 대여와 반납일이 지난 책을 한눈에 볼 수 있어요. 지난 건은 빨갛게 표시돼요.',
            '새로 가입해 승인을 기다리는 교인이 생기면 담당자에게 알림이 가요.',
            if (me.isStaff)
              '"도서관 담당자 지정"에서 승인된 교인 중 담당자를 정하거나 풀 수 있어요.',
          ],
        ),
      const _Section(
        icon: Icons.help_outline,
        title: '이럴 땐 이렇게',
        lines: [
          '화면이 예전 그대로면 앱을 완전히 닫았다가 두 번 다시 열어 보세요. 새 버전이 불러와져요.',
          '바코드가 계속 안 읽히면 밝은 곳에서 책을 평평하게 두고 사진으로 찍어 보세요.',
          '그래도 안 되면 도서관 담당자에게 알려 주세요.',
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('도움말')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '소망 도서관은 교인들이 가진 책을 서로 빌려 보는 곳이에요.\n'
                '궁금한 항목을 눌러 보세요.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _SectionTile(section: sections[i], initiallyExpanded: i == 0),
                  ],
                ],
              ),
            ),
            // 아이폰 강제 종료 원인 분리용 실험 스위치 (임시)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: _ExperimentCard(),
            ),
            // 앱 버전 (배포 날짜) — 아이폰 문제 확인 때 어떤 버전인지 알 수 있게
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: VersionBadge(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String title;
  final List<String> lines;
  const _Section({required this.icon, required this.title, required this.lines});
}

class _SectionTile extends StatelessWidget {
  final _Section section;
  final bool initiallyExpanded;
  const _SectionTile({required this.section, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      shape: const Border(), // 펼쳤을 때 위아래 선 없애기
      collapsedShape: const Border(),
      leading: Icon(section.icon, color: theme.colorScheme.primary),
      title: Text(section.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in section.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, style: const TextStyle(height: 1.45)),
          ),
      ],
    );
  }
}

/// (임시) 아이폰에서 앱이 꺼지는 원인을 나누어 보기 위한 실험 스위치.
/// 원인이 확인되면 지운다. 값은 localStorage 에 남고, 렌더링 방식은 다시 불러와야 적용된다.
class _ExperimentCard extends StatefulWidget {
  const _ExperimentCard();

  @override
  State<_ExperimentCard> createState() => _ExperimentCardState();
}

class _ExperimentCardState extends State<_ExperimentCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = WebPlatform.engineMode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.science_outlined, color: theme.colorScheme.primary),
            title: const Text('실험 (아이폰 꺼짐 원인 찾기)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('하나씩 바꿔 가며 서가를 스크롤해 보고, 결과를 알려 주세요.'),
          ),
          SwitchListTile(
            title: const Text('표지를 <img>로 그리기 끄기'),
            subtitle: const Text('켜면 예전 방식(CanvasKit)으로 표지를 그려요 — 서가를 다시 열어야 적용'),
            value: WebPlatform.imgCoversOff,
            onChanged: (v) => setState(() => WebPlatform.imgCoversOff = v),
          ),
          SwitchListTile(
            title: const Text('표지 이미지 숨기기'),
            subtitle: const Text('표지 대신 제목 카드만 보여요'),
            value: WebPlatform.noCovers,
            onChanged: (v) => setState(() => WebPlatform.noCovers = v),
          ),
          const Divider(height: 1),
          for (final e in const [
            ('3', '해상도: 기기 그대로 (3x)', '가장 선명, 가장 느림'),
            ('2', '해상도: 2x', 'CPU 렌더링일 때 기본값 — 거의 안 느껴지는 화질 차이'),
            ('1', '해상도: 1x (최저사양)', '화질 낮음, 가장 빠름'),
          ])
            RadioListTile<String>(
              title: Text(e.$2),
              subtitle: Text(e.$3),
              value: e.$1,
              groupValue: WebPlatform.dprMode,
              onChanged: (v) {
                if (v == null) return;
                WebPlatform.dprMode = v;
                WebPlatform.reload();
              },
            ),
          const Divider(height: 1),
          RadioListTile<String>(
            title: const Text('렌더링: 자동'),
            subtitle: Text(WebPlatform.engineAutoSwitched
                ? '이 기기는 강제 종료가 감지돼 CPU 렌더링으로 자동 전환됐어요'
                : '아이폰 미니는 CPU, 그 외는 WebGL — 2번 연속 강제 종료되면 CPU 로 자동 전환'),
            value: '',
            groupValue: engine,
            onChanged: _setEngine,
          ),
          RadioListTile<String>(
            title: const Text('렌더링: WebGL 강제'),
            subtitle: const Text('아이폰에서 꺼지던 예전 방식'),
            value: 'gpu',
            groupValue: engine,
            onChanged: _setEngine,
          ),
          RadioListTile<String>(
            title: const Text('렌더링: CPU 전용'),
            subtitle: const Text('그래픽(WebGL) 메모리를 쓰지 않아요'),
            value: 'cpu',
            groupValue: engine,
            onChanged: _setEngine,
          ),
          RadioListTile<String>(
            title: const Text('렌더링: 다중 서피스(상한 2)'),
            value: 'multi',
            groupValue: engine,
            onChanged: _setEngine,
          ),
        ],
      ),
    );
  }

  void _setEngine(String? v) {
    if (v == null) return;
    WebPlatform.engineMode = v;
    WebPlatform.reload(); // 엔진 옵션은 시작할 때만 읽으므로 다시 불러온다
  }
}
