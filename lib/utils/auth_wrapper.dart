import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/email_verification_page.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:logger/logger.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = context.read<Logger>();
    logger.i('로그인 확인 중');
    final userProvider = Provider.of<UserProvider>(context);

    return FutureBuilder<bool>(
      future: userProvider.isUserLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == true) {
          if (userProvider.user != null) {
            logger.i('유저 ${userProvider.user!.email}의 로그인 성공');
            return FutureBuilder<bool>(
              future: userProvider.isEmailVerified(),
              builder: (context, verificationSnapshot) {
                if (verificationSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (verificationSnapshot.data == true) {
                  logger.i('이메일 인증 완료, SubjectPage 로드');
                  return const SubjectPage();
                } else {
                  logger.i('이메일 인증 필요, EmailVerificationPage 로드');
                  return const EmailVerificationPage();
                }
              },
            );
          } else {
            logger.i('유저 로그인 성공, 하지만 유저 정보가 없음');
            return const LoginPage();
          }
        } else {
          logger.i('유저 로그인 실패, LoginPage 표시');
          return const LoginPage();
        }
      },
    );
  }
}
