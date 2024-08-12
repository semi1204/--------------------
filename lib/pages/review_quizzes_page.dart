import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/review_quiz/subject_dropdown.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';

class ReviewQuizzesPage extends StatefulWidget {
  const ReviewQuizzesPage({super.key});

  @override
  State<ReviewQuizzesPage> createState() => _ReviewQuizzesPageState();
}

class _ReviewQuizzesPageState extends State<ReviewQuizzesPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  String? _selectedSubjectId;
  List<Quiz> _quizzesForReview = [];
  bool _isLoading = false;
  int? _currentQuizIndex;
  bool _showFeedbackButtons = false;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('ReviewQuizzesPage initialized');
    _loadQuizzesForReview();
  }

  Future<void> _loadQuizzesForReview() async {
    if (_selectedSubjectId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _userProvider.user?.uid;
      if (userId == null) {
        _logger.w('User ID is null, cannot load quizzes for review');
        return;
      }

      // 복습할 퀴즈 목록 가져오기 from quiz_service.getQuizzesForReview
      _quizzesForReview = await _quizService.getQuizzesForReview(
        userId,
        _selectedSubjectId!,
        '', // 복습은 과목 단위로 이루어짐
        _userProvider,
      );

      _logger.i('Loaded ${_quizzesForReview.length} quizzes for review');
    } catch (e) {
      _logger.e('Error loading quizzes for review: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SubjectDropdown(
            selectedSubjectId: _selectedSubjectId,
            onSubjectSelected: _handleSubjectChange,
          ),
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_quizzesForReview.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  itemCount: _quizzesForReview.length,
                  itemBuilder: (context, index) {
                    final quiz = _quizzesForReview[index];
                    _logger.d('Building ReviewPageCard for quiz: ${quiz.id}');
                    return ReviewPageCard(
                      key: ValueKey(quiz.id),
                      quiz: quiz,
                      isAdmin: userProvider.isAdmin,
                      questionNumber: index + 1,
                      onAnswerSelected: (answerIndex) =>
                          _handleAnswerSelected(quiz, answerIndex),
                      // onDeleteReview: () => _deleteReview(
                      //     quiz), // --------- TODO : 복습 목록에서 제거하는 버튼, Explanation 페이지의 복습목록 제거 버튼으로 대체해야 함. ---------//
                      subjectId: _selectedSubjectId!,
                      quizTypeId: quiz.typeId,
                      nextReviewDate: userProvider
                              .getNextReviewDate(
                                _selectedSubjectId!,
                                quiz.typeId,
                                quiz.id,
                              )
                              ?.toIso8601String() ??
                          DateTime.now().toIso8601String(),
                      buildFeedbackButtons: () => _buildFeedbackButtons(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration,
              size: 80, color: Color.fromARGB(255, 255, 153, 0)),
          SizedBox(height: 20),
          Text('와! 모든 퀴즈를 완료했어요! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('잠시 후에 다시 확인해보세요!'),
        ],
      ),
    );
  }

  Future<void> _handleAnswerSelected(Quiz quiz, int answerIndex) async {
    _logger.i('Answer selected for quiz ${quiz.id}: $answerIndex');
    final isCorrect = quiz.correctOptionIndex == answerIndex;

    await _userProvider.updateUserQuizData(
      _selectedSubjectId!,
      quiz.typeId,
      quiz.id,
      isCorrect,
      selectedOptionIndex: answerIndex,
    );

    setState(() {
      _currentQuizIndex = _quizzesForReview.indexOf(quiz);
      _showFeedbackButtons = true;
    });

    _logger.d('Quiz data updated. isCorrect: $isCorrect');
  }

  Widget _buildFeedbackButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () => _giveFeedback(false),
          child: const Text('어려워요 🤔'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 245, 127, 121),
            minimumSize: const Size(100, 36), // 버튼 크기 조정
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        ElevatedButton(
          onPressed: () => _giveFeedback(true),
          child: const Text('이제 알겠어요! 😊'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 176, 243, 179),
            minimumSize: const Size(100, 36), // 버튼 크기 조정
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _giveFeedback(bool isUnderstandingImproved) async {
    if (_currentQuizIndex != null) {
      final quiz = _quizzesForReview[_currentQuizIndex!];
      final userAnswer = _userProvider.getUserAnswer(
        _selectedSubjectId!,
        quiz.typeId,
        quiz.id,
      );

      if (userAnswer != null) {
        final isCorrect = quiz.correctOptionIndex == userAnswer;

        await _userProvider.updateUserQuizData(
          _selectedSubjectId!,
          quiz.typeId,
          quiz.id,
          isCorrect,
          isUnderstandingImproved: isUnderstandingImproved,
          selectedOptionIndex: userAnswer,
        );

        setState(() {
          _showFeedbackButtons = false;
          _currentQuizIndex = null;
        });

        await _refreshQuizzes();
      } else {
        _logger.w('사용자 답변이 없습니다. 퀴즈 ID: ${quiz.id}');
      }
    }
  }

  Future<void> _refreshQuizzes() async {
    _logger.i('Manually refreshing quiz list');
    setState(() {
      _isLoading = true;
    });
    await _loadQuizzesForReview();
    setState(() {
      _isLoading = false;
    });
  }

// ------TODO : 복습 목록에서 제거하는 버튼, Explanation 페이지의 복습목록 제거 버튼으로 대체해야 함. ---------//
  // Future<void> _deleteReview(Quiz quiz) async {
  //   _logger.i('Deleting review for quiz: ${quiz.id}');
  //   try {
  //     await _userProvider.updateUserQuizData(
  //       _selectedSubjectId!,
  //       quiz.typeId,
  //       quiz.id,
  //       false,
  //       toggleReviewStatus: false,
  //     );
  //     setState(() {
  //       _quizzesForReview.removeWhere((q) => q.id == quiz.id);
  //     });
  //     _logger.i('Review deleted successfully');

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('복습 목록에서 제거되었습니다.')),
  //       );
  //     }
  //   } catch (e) {
  //     _logger.e('Error deleting review: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('복습 삭제 중 오류가 발생했습니다. 다시 시도해주세요.')),
  //       );
  //     }
  //   }
  // }

  void _handleSubjectChange(String? newSubjectId) {
    setState(() {
      _selectedSubjectId = newSubjectId;
    });
    _loadQuizzesForReview();
  }
}
