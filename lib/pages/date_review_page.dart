import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:nursing_quiz_app_6/widgets/date_select.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class DateReviewPage extends StatefulWidget {
  const DateReviewPage({super.key});

  @override
  State<DateReviewPage> createState() => _DateReviewPageState();
}

class _DateReviewPageState extends State<DateReviewPage> {
  DateTime _selectedDate = DateTime.now();
  Map<Subject, Map<String, List<Quiz>>> _quizzesBySubject = {};
  bool _isLoading = false;
  final _logger = Logger();
  final Map<String, int> _selectedAnswers = {};
  final Map<String, int> _questionNumbers = {};

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  void _assignQuestionNumbers() {
    int number = 1;
    _questionNumbers.clear();

    for (var subject in _quizzesBySubject.keys) {
      final quizzesByType = _quizzesBySubject[subject]!;
      for (var entry in quizzesByType.entries) {
        final quizzes = entry.value;
        for (var quiz in quizzes) {
          _questionNumbers[quiz.id] = number++;
        }
      }
    }
  }

  Future<void> _loadQuizzes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedAnswers.clear();
      _questionNumbers.clear();
    });

    final quizService = context.read<QuizService>();
    final userId = context.read<UserProvider>().user?.uid;
    final userProvider = context.read<UserProvider>();

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final subjects = await quizService.getSubjects();
      Map<Subject, Map<String, List<Quiz>>> quizzesBySubject = {};

      final quizTypesFutures = subjects.map((subject) async {
        final quizTypes = await quizService.getQuizTypes(subject.id);
        return MapEntry(subject, quizTypes);
      });

      final subjectsWithQuizTypes = await Future.wait(quizTypesFutures);

      for (var entry in subjectsWithQuizTypes) {
        final subject = entry.key;
        final quizTypes = entry.value;

        final quizzesFutures = quizTypes.map((quizType) async {
          final quizzes = await quizService.getQuizzesForDate(
            userId,
            subject.id,
            quizType.id,
            _selectedDate,
          );

          final incorrectQuizzes = quizzes.where((quiz) {
            final quizData = userProvider.getUserQuizData()[subject.id]
                ?[quizType.id]?[quiz.id];
            if (quizData == null) return false;

            final selectedOptionIndex = quizData['selectedOptionIndex'] as int?;
            if (selectedOptionIndex == null) return false;

            return selectedOptionIndex != quiz.correctOptionIndex;
          }).toList();

          return MapEntry(quizType.id, incorrectQuizzes);
        });

        final quizzesByType = Map.fromEntries(
          (await Future.wait(quizzesFutures))
              .where((entry) => entry.value.isNotEmpty),
        );

        if (quizzesByType.isNotEmpty) {
          quizzesBySubject[subject] = quizzesByType;
        }
      }

      if (mounted) {
        setState(() {
          _quizzesBySubject = quizzesBySubject;
          _isLoading = false;
        });
        _assignQuestionNumbers();
      }
    } catch (e) {
      _logger.e('Failed to load quizzes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈를 불러오는 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _handleAnswerSelected(
      String subjectId, String quizTypeId, Quiz quiz, int index) {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.user?.uid;
    if (userId != null) {
      setState(() {
        _selectedAnswers['${quiz.id}'] = index;
      });
      context.read<QuizService>().updateUserQuizData(
            userId,
            subjectId,
            quizTypeId,
            quiz.id,
            index == quiz.correctOptionIndex,
            selectedOptionIndex: index,
          );
    }
  }

  void _handleResetQuiz(String subjectId, String quizTypeId, String quizId) {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.user?.uid;
    if (userId != null) {
      setState(() {
        _selectedAnswers.remove(quizId);
      });
      context.read<QuizService>().resetSelectedOption(
            userId,
            subjectId,
            quizTypeId,
            quizId,
          );
    }
  }

  Widget _buildQuizCard(Quiz quiz, String subjectId, String quizTypeId) {
    final questionNumber = _questionNumbers[quiz.id] ?? 0;
    return QuizPageCard(
      key: ValueKey(quiz.id),
      quiz: quiz,
      questionNumber: questionNumber,
      subjectId: subjectId,
      quizTypeId: quizTypeId,
      nextReviewDate: '',
      onAnswerSelected: (index) => _handleAnswerSelected(
        subjectId,
        quizTypeId,
        quiz,
        index,
      ),
      onResetQuiz: () => _handleResetQuiz(
        subjectId,
        quizTypeId,
        quiz.id,
      ),
      isQuizPage: true,
      rebuildExplanation: false,
      selectedOptionIndex: _selectedAnswers['${quiz.id}'],
    );
  }

  Widget _buildSubjectSection(
      Subject subject, Map<String, List<Quiz>> quizzesByType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: context.watch<ThemeProvider>().isDarkMode
                ? Colors.grey[850]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '# ${subject.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.watch<ThemeProvider>().isDarkMode
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
        ),
        ...quizzesByType.entries.expand((entry) {
          final quizTypeId = entry.key;
          final quizzes = entry.value;
          return quizzes
              .map((quiz) => _buildQuizCard(quiz, subject.id, quizTypeId));
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
              ),
            )
          : _quizzesBySubject.isEmpty
              ? Column(
                  children: [
                    TimelineView(
                      selectedDate: _selectedDate,
                      onSelectedDateChanged: (date) {
                        setState(() => _selectedDate = date);
                        _loadQuizzes();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '이 날짜에 틀린 문제가 없습니다',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount:
                      _quizzesBySubject.length + 1, // +1 for TimelineView
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return TimelineView(
                        selectedDate: _selectedDate,
                        onSelectedDateChanged: (date) {
                          setState(() => _selectedDate = date);
                          _loadQuizzes();
                        },
                      );
                    }
                    final subjectIndex = index - 1;
                    final subject =
                        _quizzesBySubject.keys.elementAt(subjectIndex);
                    final quizzesByType = _quizzesBySubject[subject]!;
                    return _buildSubjectSection(subject, quizzesByType);
                  },
                ),
    );
  }
}
