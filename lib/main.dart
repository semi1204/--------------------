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

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<Logger>.value(value: logger),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider<QuizService>(create: (_) => QuizService()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(
          create: (context) => QuizProvider(
            context.read<QuizService>(),
            context.read<UserProvider>(),
            context.read<Logger>(),
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
          title: 'Nursing Quiz App',
          theme: themeProvider.currentTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
