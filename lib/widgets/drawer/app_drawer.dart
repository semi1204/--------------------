import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/home_page.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import 'drawer_header.dart';
import 'package:logger/logger.dart';
import '../common_widgets.dart';
import '../../providers/theme_provider.dart';
import '../../services/quiz_service.dart';
import '../../services/background_sync_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final quizService = Provider.of<QuizService>(context, listen: false);
    final backgroundSyncService = BackgroundSyncService(quizService);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const AppDrawerHeader(),
          if (userProvider.user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('로그인'),
              onTap: () {
                logger.i('Login button tapped from Drawer');
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginPage(
                          isFromDrawer: true)), // Add isFromDrawer parameter
                );
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () async {
                logger.i('Logout button tapped');
                await authService.signOut();
                userProvider.setUser(null);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  CommonSnackBar(message: '👋 로그아웃 완료! 다음에 또 만나요 😊'),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('홈'),
            onTap: () {
              logger.i('Home menu item tapped');
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DraggablePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () {
              logger.i('Settings menu item tapped');
              Navigator.pop(context);
              // TODO: Navigate to settings page
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('전체 데이터 동기화'),
            onTap: () async {
              logger.i('Sync All Data button tapped');
              try {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  CommonSnackBar(
                    message: '데이터 동기화 시작... 잠시만 기다려주세요.',
                  ),
                );

                await userProvider.syncUserData();
                await backgroundSyncService.syncAllData();

                ScaffoldMessenger.of(context).showSnackBar(
                  CommonSnackBar(
                    message: '모든 데이터 동기화 완료! 🔄',
                  ),
                );
              } catch (e) {
                logger.e('Error syncing all data: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  CommonSnackBar(
                    message: '동기화 중 오류가 발생했습니다. 다시 시도해주세요.',
                    backgroundColor: Colors.red[300]!,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            title: Text(themeProvider.isDarkMode ? '라이트 모드' : '다크 모드'),
            onTap: () {
              logger.i('Theme toggle button tapped');
              themeProvider.toggleTheme();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
