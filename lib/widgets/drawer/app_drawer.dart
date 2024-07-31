import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import 'drawer_header.dart';
import 'package:logger/logger.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const AppDrawerHeader(),
          // 수정: 사용자 로그인 상태에 따라 동적으로 버튼 표시
          if (userProvider.user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () {
                logger.i('Login button tapped');
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                logger.i('Logout button tapped');
                await authService.signOut();
                userProvider.setUser(null);
                Navigator.pop(context);
                // 추가: 로그아웃 후 스낵바 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Successfully logged out')),
                );
              },
            ),
          // 추가: 기타 드로어 메뉴 항목들
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              logger.i('Home menu item tapped');
              Navigator.pop(context);
              // TODO: Navigate to home page
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              logger.i('Settings menu item tapped');
              Navigator.pop(context);
              // TODO: Navigate to settings page
            },
          ),
        ],
      ),
    );
  }
}
