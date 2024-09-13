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
        color: themeProvider.isDarkMode
            ? ThemeProvider.darkModeSurface
            : ThemeProvider.primaryColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 구글 폰트와 이모지를 사용하여 환영 메시지 표시
          Text(
            user != null ? '안녕하세요, ${user.displayName}님! 👋' : '환영합니다! 👋',
            style: getAppTextStyle(
              context,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ).copyWith(
                color:
                    themeProvider.isDarkMode ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 6),
          // 사용자 이메일 또는 로그인 안내 메시지 표시
          Text(
            user != null ? '${user.email} 📧' : '로그인해 주세요 🔑',
            style: getAppTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ).copyWith(
                color:
                    themeProvider.isDarkMode ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }
}
