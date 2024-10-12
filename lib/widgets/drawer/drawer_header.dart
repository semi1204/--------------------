import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/constants.dart';

class AppDrawerHeader extends StatelessWidget {
  const AppDrawerHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = userProvider.user;

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeProvider.isDarkMode
              ? [ThemeProvider.darkModeSurface, const Color(0xFF2C2C2C)]
              : [ThemeProvider.primaryColor, const Color(0xFFE1F5FE)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showProfileOptions(context, userProvider),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                      width: 2,
                    ),
                    image: user?.photoURL != null
                        ? DecorationImage(
                            image: NetworkImage(user!.photoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.photoURL == null
                      ? Icon(
                          Icons.person,
                          size: 40,
                          color: themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: getAppTextStyle(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ).copyWith(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                      ),
                      child: Text(
                        user != null
                            ? '안녕하세요,\n${user.displayName}님! 👋'
                            : '환영합니다! 👋',
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: getAppTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ).copyWith(
                        color: themeProvider.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                      child: Text(
                        user != null ? '${user.email} 📧' : '로그인해 주세요 🔑',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 2,
            width: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeProvider.isDarkMode
                    ? [Colors.white24, Colors.white]
                    : [
                        ThemeProvider.primaryColor.withOpacity(0.3),
                        ThemeProvider.primaryColor
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(BuildContext context, UserProvider userProvider) {
    if (userProvider.user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('회원탈퇴'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(context, userProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context, UserProvider userProvider) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('회원탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('정말로 회원탈퇴를 하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  hintText: '계정 삭제를 위해 비밀번호를 입력해주세요',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('탈퇴'),
              onPressed: () async {
                try {
                  await userProvider.deleteAccount(passwordController.text);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(); // Close the dialog
                    Navigator.of(dialogContext).pop(); // Close the drawer
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('회원탈퇴가 완료되었습니다.')),
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(); // Close the dialog
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('회원탈퇴 중 오류가 발생했습니다: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
