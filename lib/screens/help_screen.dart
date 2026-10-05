import 'package:flutter/material.dart';

import '../models/library_user.dart';
import '../widgets/page_frame.dart';

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
          '"대여 가능만"을 켜면 지금 빌릴 수 있는 책만 보여요.',
          '권수 옆 "보기 방식" 메뉴에서 표지 크기(작게·보통·크게)나 목록으로 바꿀 수 있어요.',
          '흐리게 보이는 책은 지금 빌릴 수 없는 책이에요.',
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
          '책을 등록·수정할 때 "친구에게만 공개"를 켜면 서로 친구인 사람만 그 책을 보고 신청할 수 있어요. 내 책 목록에는 "친구 공개"로 표시돼요.',
        ],
      ),
      const _Section(
        icon: Icons.people_outline,
        title: '친구 만들기',
        lines: [
          '"내 정보 → 친구"에서 이름으로 찾아 친구 신청을 보낼 수 있어요.',
          '서가에서 책을 눌렀을 때 소장자 이름 아래의 "친구 신청" 버튼으로도 바로 신청할 수 있어요.',
          '상대가 수락하면 서로 친구가 돼요. 신청이 오면 알림이 가고, "내 정보 → 친구"에서 수락하거나 거절해요.',
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
          '신청·수락 뒤에도 날짜·시간·장소를 바꾸고 싶으면 대여 화면에서 일정 변경을 하세요. 상대방에게 알림이 가요.',
          '신청 중이거나 수락된 대여는 두 사람 모두 취소할 수 있어요.',
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
        ],
      ),
      if (me.isLibraryAdmin)
        _Section(
          icon: Icons.admin_panel_settings_outlined,
          title: '담당자 안내',
          lines: [
            '"내 정보 → 도서관 관리"에서 교인 초대 링크를 만들고 가입을 승인해요.',
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
