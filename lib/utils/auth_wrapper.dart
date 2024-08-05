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
    logger.i('Building AuthWrapper');
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
          logger.i('User is logged in, loading DraggablePage');
          return const DraggablePage();
        } else {
          logger.i('User is not logged in, showing LoginPage');
          return const LoginPage();
        }
      },
    );
  }
}
