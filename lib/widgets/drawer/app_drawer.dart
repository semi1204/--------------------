import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/home_page.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import 'drawer_header.dart';
import 'package:logger/logger.dart';
import '../common_widgets.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
          if (userProvider.user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
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
              title: const Text('Logout'),
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
            title: const Text('Home'),
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
            title: const Text('Settings'),
            onTap: () {
              logger.i('Settings menu item tapped');
              Navigator.pop(context);
              // TODO: Navigate to settings page
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync User Info'),
            onTap: () async {
              logger.i('Sync User Info button tapped');
              await userProvider.syncUserData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                CommonSnackBar(
                  message: '사용자 데이터 동기화 완료! 🔄',
                  backgroundColor: Colors.green[300]!,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
