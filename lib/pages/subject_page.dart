import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../providers/subject_provider.dart';
import '../providers/theme_provider.dart';
import 'quiz_type_page.dart';
import 'review_quizzes_page.dart';
import 'add_quiz_page.dart';
import '../widgets/drawer/app_drawer.dart';
import '../utils/constants.dart';
import '../widgets/linked_title.dart'; // Add this import

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
              title: LinkedTitle(
                titles: ['과목'],
                onTap: (_) {}, // No action needed for the root page
              ),
              centerTitle: true,
              elevation: 0,
            ),
          ),
          drawer: const AppDrawer(),
          body: IndexedStack(
            index: subjectProvider.selectedIndex,
            children: [
              _buildSubjectList(subjectProvider, themeProvider),
              const ReviewQuizzesPage(),
              if (Provider.of<UserProvider>(context, listen: false).isAdmin)
                const AddQuizPage(),
            ],
          ),
          bottomNavigationBar:
              _buildBottomNavigationBar(subjectProvider, themeProvider),
        );
      },
    );
  }

  Widget _buildSubjectList(
      SubjectProvider subjectProvider, ThemeProvider themeProvider) {
    if (subjectProvider.subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      itemCount: subjectProvider.subjects.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: 10), // 카드 사이의 간격
      itemBuilder: (context, index) {
        final subject = subjectProvider.subjects[index];
        return Card(
          elevation: 0.3,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            // Added Padding widget for slight padding around the ListTile
            padding: const EdgeInsets.all(
                2.0), // Adjusted padding value for better spacing between cards
            child: ListTile(
              title: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Text(
                    subject.name,
                    style: getAppTextStyle(
                      context,
                      fontSize: 17,
                    ).copyWith(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                  );
                },
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizTypePage(subject: subject),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(
      SubjectProvider subjectProvider, ThemeProvider themeProvider) {
    return BottomNavigationBar(
      currentIndex: subjectProvider.selectedIndex,
      onTap: subjectProvider.setSelectedIndex,
      iconSize: 20,
      selectedFontSize: 12,
      unselectedFontSize: 10,
      selectedItemColor: themeProvider.isDarkMode
          ? Colors.white
          : Color.fromARGB(255, 50, 90, 135),
      unselectedItemColor: themeProvider.isDarkMode
          ? Color.fromARGB(255, 153, 151, 151)
          : Color.fromARGB(255, 119, 117, 117),
      backgroundColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.white,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.local_library), label: '과목별 기출'),
        const BottomNavigationBarItem(icon: Icon(Icons.refresh), label: '복습하기'),
        if (Provider.of<UserProvider>(context, listen: false).isAdmin)
          const BottomNavigationBarItem(icon: Icon(Icons.add), label: '퀴즈 추가'),
      ],
    );
  }
}
