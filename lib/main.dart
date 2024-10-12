import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:nursing_quiz_app_6/utils/auth_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/services/payment_service.dart'; // Add this import
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
  final paymentService = PaymentService(); // Add this line

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<Logger>.value(value: logger),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<PaymentService>.value(value: paymentService), // Add this line
        ChangeNotifierProvider(create: (_) => UserProvider()),
        Provider<QuizService>.value(value: quizService),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(
          create: (context) => QuizProvider(
            context.read<QuizService>(),
            context.read<UserProvider>(),
            context.read<Logger>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReviewQuizzesProvider(
            quizService,
            Logger(),
            context.read<UserProvider>().user?.uid,
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
    // Trigger data synchronization on app start
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.syncUserData();

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
