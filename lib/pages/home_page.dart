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

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('DraggablePage 초기화');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logger.i('DraggablePage 빌드');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        _logger.i(
            'DraggablePage 빌드. 로그인 여부: ${userProvider.user != null}. 관리자 여부: ${userProvider.isAdmin}');

        final List<Widget> _pages = [
          SubjectPage(key: const PageStorageKey('과목')),
          const ReviewQuizzesPage(key: PageStorageKey('복습')),
          if (userProvider.isAdmin)
            const AddQuizPage(key: PageStorageKey('퀴즈 추가')),
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
              _logger.i('유저가 페이지 인덱스 $index로 이동');
            },
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home), label: '과목'),
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
