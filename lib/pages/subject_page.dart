import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../providers/subject_provider.dart';
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
    return Consumer<SubjectProvider>(
      builder: (context, subjectProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('과목'),
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
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.book), label: '과목'),
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
