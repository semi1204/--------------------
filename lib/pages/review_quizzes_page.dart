import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/review_quiz/subject_dropdown.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _logLocalData();
    _loadQuizzesForReview();
  }

  Future<void> _loadQuizzesForReview() async {
    if (_selectedSubjectId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 모든 퀴즈를 가져옴
      final allQuizzes = await _quizService.getQuizzes(_selectedSubjectId!, '');
      final now = DateTime.now();

      // 복습할 퀴즈 필터링 시작
      _quizzesForReview = allQuizzes.where((quiz) {
        // 다음 복습 날짜가 현재 날짜보다 이전인 퀴즈만 가져옴
        final nextReviewDate = _userProvider.getNextReviewDate(
          // TODO: 복습할 퀴즈를 가져오는 대해서 getQuizzesForReview 메소드 사용해야하면서 추가적으로 필터링을 해야함
          _selectedSubjectId!,
          quiz.typeId,
          quiz.id,
        );
        return nextReviewDate != null && nextReviewDate.isBefore(now);
      }).toList();

      _logger.i('Loaded ${_quizzesForReview.length} quizzes for review');
    } catch (e) {
      _logger.e('Error loading quizzes for review: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userProvider.user?.uid;
    if (userId != null) {
      final localData = prefs.getString('user_quiz_data_$userId');
      if (localData != null) {
        _logger.d('로컬 저장소의 퀴즈 데이터: $localData');
      } else {
        _logger.d('로컬 저장소에 저장된 퀴즈 데이터가 없습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SubjectDropdown(
            selectedSubjectId: _selectedSubjectId,
            onSubjectSelected: (String? newValue) {
              setState(() {
                _selectedSubjectId = newValue;
              });
              if (newValue != null) {
                _loadQuizzesForReview();
              }
            },
          ),
          Expanded(
            child: _selectedSubjectId == null
                ? const Center(child: Text('과목을 선택해주세요'))
                : RefreshIndicator(
                    onRefresh: _refreshQuizzes,
                    child: _buildQuizList(),
                  ),
          ),
        ],
      ),
    );
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

  Widget _buildQuizList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quizzesForReview.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration,
                size: 80, color: Color.fromARGB(255, 255, 153, 0)),
            SizedBox(height: 20),
            Text(
              '와! 모든 퀴즈를 완료했어요! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('잠시 후에 다시 확인해보세요!'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _quizzesForReview.length,
      itemBuilder: (context, index) {
        final quiz = _quizzesForReview[index];
        final nextReviewTime = _userProvider.getNextReviewTimeString(
          _selectedSubjectId!,
          quiz.typeId,
          quiz.id,
        );

        return ReviewPageCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          isAdmin: _userProvider.isAdmin,
          questionNumber: index + 1,
          onAnswerSelected: (answerIndex) async {
            final startTime = DateTime.now();
            final isCorrect = quiz.correctOptionIndex == answerIndex;
            final endTime = DateTime.now();
            final answerTime = endTime.difference(startTime);

            await _userProvider.updateUserQuizData(
              _selectedSubjectId!,
              quiz.typeId,
              quiz.id,
              isCorrect,
              answerTime: answerTime,
              selectedOptionIndex: answerIndex,
            );

            setState(() {
              _currentQuizIndex = index;
              _showFeedbackButtons = true;
            });
          },
          onDeleteReview: () => _deleteReview(quiz),
          subjectId: _selectedSubjectId!,
          quizTypeId: quiz.typeId,
          nextReviewDate: _userProvider
                  .getNextReviewDate(
                    _selectedSubjectId!, // 동적으로 변하는 값임
                    quiz.typeId,
                    quiz.id,
                  )
                  ?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          buildFeedbackButtons: () => _buildFeedbackButtons(),
        );
      },
    );
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
        // 사용자 답변이 없는 경우 처리
        _logger.w('사용자 답변이 없습니다. 퀴즈 ID: ${quiz.id}');
        // 적절한 오류 처리 또는 사용자에게 알림
      }
    }
  }

  Future<void> _deleteReview(Quiz quiz) async {
    _logger.i('Deleting review for quiz: ${quiz.id}');
    try {
      await _userProvider.deleteUserQuizData(
        _userProvider.user!.uid,
        _selectedSubjectId!,
        quiz.typeId,
        quiz.id,
      );
      setState(() {
        _quizzesForReview.removeWhere((q) => q.id == quiz.id);
      });
      _logger.i('Review deleted successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted successfully')),
        );
      }
    } catch (e) {
      _logger.e('Error deleting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete review. Please try again.')),
        );
      }
    }
  }
}
