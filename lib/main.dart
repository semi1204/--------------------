import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:nursing_quiz_app_6/providers/quiz_view_mode_provider.dart';
import 'package:nursing_quiz_app_6/services/analytics_service.dart';
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
import 'package:nursing_quiz_app_6/utils/cache_manager.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize CacheManager
  await CacheManager.init();

  // Enable Firebase Analytics collection
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  final paymentService = PaymentService(logger: logger);
  await paymentService.initialize();

  final quizService = QuizService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<Logger>.value(value: logger),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<PaymentService>.value(
            value: paymentService), // Changed this line
        ChangeNotifierProvider(
            create: (context) =>
                UserProvider(paymentService: context.read<PaymentService>())),
        Provider<QuizService>.value(value: quizService),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(
          create: (context) => QuizProvider(
            context.read<QuizService>(),
            context.read<UserProvider>(),
            context.read<Logger>(),
            context.read<PaymentService>(),
            context.read<AnalyticsService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReviewQuizzesProvider(
            context.read<QuizService>(),
            context.read<Logger>(),
            context.read<UserProvider>().user?.uid,
          ),
        ),
        ChangeNotifierProvider(create: (_) => QuizViewModeProvider()),
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
          title: '딸깍복습 간호사 국가고시',
          theme: themeProvider.currentTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
