import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/incorrect_answer_page.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/pages/add_quiz_page.dart';
import 'package:nursing_quiz_app_6/widgets/drawer/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('HomePage initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.i('HomePage built');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _logger.i(
            'Building HomePage. User logged in: ${userProvider.user != null}. Is admin: ${userProvider.isAdmin}');

        final List<Widget> _pages = [
          SubjectPage(key: PageStorageKey('subject')),
          SubjectPage(key: PageStorageKey('quiz')),
          const IncorrectAnswersPage(key: PageStorageKey('incorrect')),
          if (userProvider.isAdmin)
            const AddQuizPage(key: PageStorageKey('add_quiz')),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nursing Quiz App'),
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
              _logger.i('User navigated to page index: $index');
            },
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.home), label: 'Home'),
              const NavigationDestination(
                  icon: Icon(Icons.quiz), label: 'Quiz'),
              const NavigationDestination(
                  icon: Icon(Icons.error_outline), label: 'Incorrect'),
              if (userProvider.isAdmin)
                const NavigationDestination(
                    icon: Icon(Icons.add), label: 'Add Quiz'),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _logger.i('HomePage disposed');
    super.dispose();
  }
}
