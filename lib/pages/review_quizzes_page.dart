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

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('복습 페이지 초기화 완료');
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
        _logger.w('사용자 ID가 없습니다. 복습 카드를 로드할 수 없음');
        return;
      }

      _quizzesForReview = await _quizService.getQuizzesForReview(
        userId,
        _selectedSubjectId!,
        '', // 복습은 과목 단위로 이루어짐
      );

      _logger.i('복습 카드 ${_quizzesForReview.length}개 로드 완료');
    } catch (e) {
      _logger.e('퀴즈 복습 데이터를 불러올 수 없음: $e');
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
                    _logger.d('복습 페이지 카드 빌드: quizId=${quiz.id}');
                    return ReviewPageCard(
                      key: ValueKey(quiz.id),
                      quiz: quiz,
                      isAdmin: userProvider.isAdmin,
                      questionNumber: index + 1,
                      onAnswerSelected: (answerIndex) =>
                          _handleAnswerSelected(quiz, answerIndex),
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
                      buildFeedbackButtons: _buildFeedbackButtons,
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
    _logger.i('복습 페이지 답변 선택: quizId=${quiz.id}, answerIndex=$answerIndex');
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
    });

    _logger.d('복습 페이지 답변 업데이트: isCorrect=$isCorrect');
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
      final userData = _userProvider.getUserQuizData();
      final userAnswer = userData[_selectedSubjectId]?[quiz.typeId]?[quiz.id]
          ?['selectedOptionIndex'] as int?;

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
          _currentQuizIndex = null;
        });

        await _refreshQuizzes();
      } else {
        _logger.w('사용자 답변이 없습니다. 퀴즈 ID: ${quiz.id}');
      }
    }
  }

  Future<void> _refreshQuizzes() async {
    _logger.i('복습 페이지 수동 새로고침');
    setState(() {
      _isLoading = true;
    });
    await _loadQuizzesForReview();
    setState(() {
      _isLoading = false;
    });
  }

  void _handleSubjectChange(String? newSubjectId) {
    setState(() {
      _selectedSubjectId = newSubjectId;
    });
    _loadQuizzesForReview();
  }
}
