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

const Color primaryColor = Color(0xFF4A90E2); // 밝은 파란색
const Color secondaryColor = Color(0xFF50E3C2); // 민트색

// 다크 모드를 위한 회색 톤의 색상 정의
const Color darkModeBackground = Color(0xFF303030); // 어두운 회색
const Color darkModeSurface = Color(0xFF424242); // 조금 더 밝은 회색

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        Provider<Logger>.value(value: logger),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider<QuizService>(create: (_) => QuizService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(
            create: (context) => QuizProvider(
                  context.read<QuizService>(),
                  context.read<UserProvider>(),
                  context.read<Logger>(),
                )),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    logger.i('Building MyApp');
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Nursing Quiz App',
          theme: themeProvider.isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: primaryColor,
                    secondary: secondaryColor,
                    surface: darkModeSurface,
                    // 필요에 따라 다른 색상들도 조정
                  ),
                  scaffoldBackgroundColor: darkModeBackground,
                  cardColor: darkModeSurface,
                  // 다른 위젯들의 색상도 필요에 따라 조정
                )
              : ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: primaryColor,
                    brightness: Brightness.light,
                  ).copyWith(secondary: secondaryColor),
                  useMaterial3: true,
                ),
          home: const AuthWrapper(),
        );
      },
    );
  }
}
