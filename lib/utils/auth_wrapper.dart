import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/pages/home_page.dart' show DraggablePage;
import 'package:logger/logger.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = context.read<Logger>();
    logger.i('로그인 확인 중');
    final userProvider = Provider.of<UserProvider>(context);

    // 주의 : 반드시 FutureBuilder를 사용해야 합니다.
    return FutureBuilder<bool>(
      future: userProvider.isUserLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == true) {
          logger.i('유저${userProvider.user!.email}의 로그인 성공, DraggablePage 로드');
          return const DraggablePage();
        } else {
          logger.i('유저${userProvider.user!.email}의 로그인 실패, LoginPage 표시');
          return const LoginPage();
        }
      },
    );
  }
}
