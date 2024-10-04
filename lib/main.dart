import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:nursing_quiz_app_6/utils/auth_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:nursing_quiz_app_6/providers/subject_provider.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart'; // 추가

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final quizService = QuizService();
  final userProvider = UserProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<Logger>.value(value: logger),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider.value(value: userProvider),
        Provider<QuizService>.value(value: quizService),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(
          create: (context) => QuizProvider(
            context.read<QuizService>(),
            context.read<UserProvider>(),
            context.read<Logger>(),
          ),
        ),
        ProxyProvider<UserProvider, ReviewQuizzesProvider>(
          update: (context, userProvider, previous) => ReviewQuizzesProvider(
            quizService,
            logger,
            userProvider.user?.uid,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Nursing Quiz App',
          theme: themeProvider.currentTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
