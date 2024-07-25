// home_page.dart
import 'package:flutter/material.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    _logger.i(
        'Building HomePage. User logged in: ${userProvider.user != null}. Is admin: ${userProvider.isAdmin}');

    final List<Widget> _pages = [
      const SubjectPage(),
      const SubjectPage(), // Quiz page is now SubjectPage
      if (userProvider.isAdmin) const AddQuizPage(),
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.quiz),
            label: 'Quiz',
          ),
          if (userProvider.isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.add),
              label: 'Add Quiz',
            ),
        ],
      ),
    );
  }
}
