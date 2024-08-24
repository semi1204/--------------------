import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../providers/subject_provider.dart';
import '../providers/theme_provider.dart';
import 'quiz_type_page.dart';
import 'review_quizzes_page.dart';
import 'add_quiz_page.dart';
import '../widgets/drawer/app_drawer.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  _SubjectPageState createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SubjectProvider>(context, listen: false).loadSubjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SubjectProvider, ThemeProvider>(
      builder: (context, subjectProvider, themeProvider, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight / 1.4),
            child: AppBar(
              title: const Text(
                '과목',
                style: TextStyle(fontSize: 18),
              ),
              centerTitle: true,
              elevation: 0,
            ),
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(
            index: subjectProvider.selectedIndex,
            children: [
              _buildSubjectList(subjectProvider),
              const ReviewQuizzesPage(),
              if (Provider.of<UserProvider>(context, listen: false).isAdmin)
                const AddQuizPage(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: subjectProvider.selectedIndex,
            onTap: (index) {
              subjectProvider.setSelectedIndex(index);
            },
            iconSize: 20,
            selectedFontSize: 12,
            unselectedFontSize: 10,
            selectedItemColor: themeProvider.isDarkMode
                ? Colors.white
                : Theme.of(context).primaryColor,
            unselectedItemColor: themeProvider.isDarkMode
                ? Colors.grey[300] // 다크 모드일 때 더 어두운 회색
                : Colors.grey[300],
            backgroundColor: themeProvider.isDarkMode
                ? Colors.grey[800] // 다크 모드일 때 더 어두운 배경색
                : Colors.white,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.book), label: '과목별 문제'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.refresh), label: '복습'),
              if (Provider.of<UserProvider>(context, listen: false).isAdmin)
                const BottomNavigationBarItem(
                    icon: Icon(Icons.add), label: '퀴즈 추가'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectList(SubjectProvider subjectProvider) {
    if (subjectProvider.subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: subjectProvider.subjects.length,
      itemBuilder: (context, index) {
        final subject = subjectProvider.subjects[index];
        return Card(
          elevation: 0.3,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(subject.name),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizTypePage(subject: subject),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
