import 'package:flutter/material.dart';

import '../models/library_user.dart';
import '../services/auth_service.dart';
import '../widgets/page_frame.dart';
import 'admin/invite_screen.dart';
import 'admin/approval_screen.dart';

/// 내 정보 + (관리자) 초대·승인 메뉴
class ProfileTab extends StatelessWidget {
  final LibraryUser me;
  const ProfileTab({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: PageFrame(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    me.name.isEmpty ? '?' : me.name.characters.first,
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                title: Text(me.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  me.groupLabel,
                  if (me.isLibrarian) '도서관 담당',
                  if (me.email.isNotEmpty) me.email,
                ].join(' · ')),
              ),
            ),

            if (me.isLibraryAdmin) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('도서관 관리',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: const Text('교인 초대 링크 만들기'),
                      subtitle: const Text('링크로 가입하면 승인 없이 바로 사용'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InviteScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.how_to_reg_outlined),
                      title: const Text('가입 승인'),
                      subtitle: const Text('초대 코드 없이 가입한 교인'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ApprovalScreen(me: me)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: AuthService.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
