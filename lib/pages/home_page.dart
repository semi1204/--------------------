import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/review_quizzes_page.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/pages/add_quiz_page.dart';
import 'package:nursing_quiz_app_6/widgets/drawer/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';

class DraggablePage extends StatefulWidget {
  const DraggablePage({Key? key}) : super(key: key);

  @override
  _DraggablePageState createState() => _DraggablePageState();
}

class _DraggablePageState extends State<DraggablePage> {
  int _selectedIndex = 0;
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('DraggablePage initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.i('DraggablePage built');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _logger.i(
            'Building DraggablePage. User logged in: ${userProvider.user != null}. Is admin: ${userProvider.isAdmin}');

        final List<Widget> _pages = [
          SubjectPage(key: const PageStorageKey('subject')),
          const ReviewQuizzesPage(key: PageStorageKey('review')),
          if (userProvider.isAdmin)
            const AddQuizPage(key: PageStorageKey('add_quiz')),
        ];

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
                  icon: Icon(Icons.home), label: 'Home'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.error_outline), label: 'Review'),
              if (userProvider.isAdmin)
                const BottomNavigationBarItem(
                    icon: Icon(Icons.add), label: 'Add Quiz'),
            ],
          ),
        );
      },
    );
  }

  Widget _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return const Text('Subjects');
      case 1:
        return const Text('Review');
      case 2:
        return const Text('Add Quiz');
      default:
        return const Text('Nursing Quiz App');
    }
  }

  @override
  void dispose() {
    _logger.i('DraggablePage disposed');
    super.dispose();
  }
}
