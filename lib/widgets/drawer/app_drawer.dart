import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/%08admin_inquiries_page.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import 'drawer_header.dart';
import 'package:logger/logger.dart';
import '../common_widgets.dart';
import '../../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ionicons/ionicons.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);

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
            leading:
                Icon(themeProvider.isDarkMode ? Ionicons.sunny : Ionicons.moon),
            title: Text(themeProvider.isDarkMode ? '라이트 모드' : '다크 모드'),
            onTap: () {
              logger.i('Theme toggle button tapped');
              themeProvider.toggleTheme();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('개발팀에게 문의하기'),
            onTap: () {
              logger.i('Contact developer button tapped');
              _showContactDialog(context, userProvider.user?.email);
            },
          ),
          if (userProvider.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('문의사항 관리'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminInquiriesPage()),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context, String? userEmail) {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: "요청사항을 입력해주세요"),
            maxLines: 5,
          ),
          actions: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: const Text('보내기'),
              onPressed: () {
                _submitInquiry(context, _controller.text, userEmail);
              },
            ),
          ],
        );
      },
    );
  }

  void _submitInquiry(
      BuildContext context, String body, String? userEmail) async {
    try {
      await FirebaseFirestore.instance.collection('inquiries').add({
        'body': body,
        'userEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의사항이 성공적으로 제출되었습니다.')),
      );
    } catch (error) {
      print('Error submitting inquiry: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('문의사항을 제출할 수 없습니다: $error')),
      );
    }
    Navigator.of(context).pop(); // Close the dialog
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
