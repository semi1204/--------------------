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
  int _questionNumber = 1;
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _questionNumber = 1;
    });

    final quizService = context.read<QuizService>();
    final userId = context.read<UserProvider>().user?.uid;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load all subjects at once
      final subjects = await quizService.getSubjects();
      Map<Subject, Map<String, List<Quiz>>> quizzesBySubject = {};

      // Load all quiz types for all subjects in parallel
      final quizTypesFutures = subjects.map((subject) async {
        final quizTypes = await quizService.getQuizTypes(subject.id);
        return MapEntry(subject, quizTypes);
      });

      final subjectsWithQuizTypes = await Future.wait(quizTypesFutures);

      // Load quizzes for each subject and quiz type in parallel
      for (var entry in subjectsWithQuizTypes) {
        final subject = entry.key;
        final quizTypes = entry.value;

        final quizzesFutures = quizTypes.map((quizType) async {
          final quizzes = await quizService.getQuizzesForReview(
            userId,
            subject.id,
            quizType.id,
            date: _selectedDate,
          );
          return MapEntry(quizType.id, quizzes);
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
      }
    } catch (e, stackTrace) {
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

  void _handleFeedbackGiven(String subjectId, String quizTypeId, Quiz quiz,
      bool isUnderstandingImproved) {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.user?.uid;
    if (userId != null) {
      context.read<QuizService>().updateUserQuizData(
            userId,
            subjectId,
            quizTypeId,
            quiz.id,
            true,
            isUnderstandingImproved: isUnderstandingImproved,
          );
    }
  }

  void _handleRemoveCard(Subject subject, String quizId) {
    setState(() {
      final updatedQuizzesBySubject =
          Map<Subject, Map<String, List<Quiz>>>.from(_quizzesBySubject);
      final subjectQuizzes = updatedQuizzesBySubject[subject];
      if (subjectQuizzes != null) {
        subjectQuizzes.forEach((typeId, quizzes) {
          subjectQuizzes[typeId] =
              quizzes.where((q) => q.id != quizId).toList();
        });
        subjectQuizzes.removeWhere((_, quizzes) => quizzes.isEmpty);
      }
      if (subjectQuizzes?.isEmpty ?? true) {
        updatedQuizzesBySubject.remove(subject);
      }
      _quizzesBySubject = updatedQuizzesBySubject;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.white,
      body: Column(
        children: [
          TimelineView(
            selectedDate: _selectedDate,
            onSelectedDateChanged: (date) {
              setState(() => _selectedDate = date);
              _loadQuizzes();
            },
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color:
                          themeProvider.isDarkMode ? Colors.white : Colors.blue,
                    ),
                  )
                : _quizzesBySubject.isEmpty
                    ? Center(
                        child: Text(
                          '이 날짜에 복습할 퀴즈가 없습니다',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _quizzesBySubject.length,
                        itemBuilder: (context, subjectIndex) {
                          final subject =
                              _quizzesBySubject.keys.elementAt(subjectIndex);
                          final quizzesByType = _quizzesBySubject[subject]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                margin: const EdgeInsets.only(bottom: 8.0),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '# ${subject.name}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                ),
                              ),
                              ...quizzesByType.entries.expand((entry) {
                                final quizTypeId = entry.key;
                                final quizzes = entry.value;

                                return quizzes.map((quiz) {
                                  final questionNumber = _questionNumber++;
                                  return ReviewPageCard(
                                    key: ValueKey('${quiz.id}_$questionNumber'),
                                    quiz: quiz,
                                    questionNumber: questionNumber,
                                    subjectId: subject.id,
                                    quizTypeId: quizTypeId,
                                    nextReviewDate: '',
                                    onAnswerSelected: (index) =>
                                        _handleAnswerSelected(
                                      subject.id,
                                      quizTypeId,
                                      quiz,
                                      index,
                                    ),
                                    onFeedbackGiven: (quiz, isImproved) =>
                                        _handleFeedbackGiven(
                                      subject.id,
                                      quizTypeId,
                                      quiz,
                                      isImproved,
                                    ),
                                    onRemoveCard: (quizId) =>
                                        _handleRemoveCard(subject, quizId),
                                  );
                                });
                              }).toList(),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
