import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/review_quizzes_page.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/pages/add_quiz_page.dart';
import 'package:nursing_quiz_app_6/widgets/drawer/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';

class DraggablePage extends StatefulWidget {
  const DraggablePage({super.key});

  @override
  DraggablePageState createState() => DraggablePageState();
}

class DraggablePageState extends State<DraggablePage> {
  int _selectedIndex = 0;
  late final Logger _logger;

  final List<Widget> _pages = [
    SubjectPage(key: const PageStorageKey('과목')),
    const ReviewQuizzesPage(key: PageStorageKey('복습')),
    const AddQuizPage(key: PageStorageKey('퀴즈 추가')),
  ];

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('DraggablePage initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _logger.i(
            'Building DraggablePage. User logged in: ${userProvider.user != null}. Is admin: ${userProvider.isAdmin}');

        return Scaffold(
          appBar: AppBar(
            title: _getAppBarTitle(_selectedIndex),
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (int index) {
              setState(() {
                _selectedIndex = index;
              });
              _logger.i('User navigated to page index: $index');
            },
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.subject), label: '과목'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.error_outline), label: '복습'),
              if (userProvider.isAdmin)
                const BottomNavigationBarItem(
                    icon: Icon(Icons.add), label: '퀴즈 추가'),
            ],
          ),
        );
      },
    );
  }

  Widget _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return const Text('과목');
      case 1:
        return const Text('복습');
      case 2:
        return const Text('퀴즈 추가');
      default:
        return const Text('간호학 퀴즈 앱');
    }
  }

  @override
  void dispose() {
    _logger.i('DraggablePage disposed');
    super.dispose();
  }
}
