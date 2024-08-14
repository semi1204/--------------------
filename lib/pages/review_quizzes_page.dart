import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';

class ReviewQuizzesPage extends StatefulWidget {
  final String? initialSubjectId;
  final String? initialQuizId;

  const ReviewQuizzesPage({
    super.key,
    this.initialSubjectId,
    this.initialQuizId,
  });

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
  List<String> _completedQuizIds =
      []; // Added: List to track completed quiz IDs

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _selectedSubjectId = widget.initialSubjectId;
    _logger.i('복습 페이지 초기화 완료');

    if (_selectedSubjectId != null) {
      _loadQuizzesForReview();
    }
  }

  Future<void> _loadQuizzesForReview() async {
    if (_selectedSubjectId == null || _selectedSubjectId!.isEmpty) {
      _logger.w('선택된 과목이 없습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _userProvider.user?.uid;
      if (userId == null) {
        _logger.w('사용자 ID가 없습니다. 복습 카드를 로드할 수 없음');
        return;
      }

      _logger.d('복습 퀴즈 로드 시작: userId=$userId, subjectId=$_selectedSubjectId');
      // --------- TODO : ReviewCard(getUserQuizData에서 데이터 파싱 중)는 복습로직을 일치시켜야 함 ---------//
      _quizzesForReview = await _quizService.getQuizzesForReview(
        userId,
        _selectedSubjectId!,
        null, // 복습은 과목별로 이루어짐. tpye을 Null로 전달
      );

      _logger.i('복습 카드 ${_quizzesForReview.length}개 로드 완료');
      _logger.d('로드된 퀴즈: ${_quizzesForReview.map((q) => q.id).toList()}');
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
          UnifiedSubjectDropdown(
            selectedSubjectId: _selectedSubjectId,
            onSubjectSelected: (String? newSubjectId) {
              setState(() {
                _selectedSubjectId = newSubjectId;
              });
              if (newSubjectId != null) {
                _loadQuizzesForReview();
              } else {
                setState(() {
                  _quizzesForReview = [];
                });
              }
            },
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
                    if (_completedQuizIds.contains(quiz.id)) {
                      return const SizedBox
                          .shrink(); // Do not show completed quizzes
                    }
                    _logger.d('Building review card: quizId=${quiz.id}');
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
                      // TODO : 피드백버튼이 '복습 목록제거'보다 위에 있어야함.
                      buildFeedbackButtons: () => _buildFeedbackButtons(quiz),
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

  Widget _buildFeedbackButtons(Quiz quiz) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: () => _giveFeedback(quiz, false),
          child: const Text('어려움 🤔', style: TextStyle(color: Colors.black)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromRGBO(255, 196, 199, 1),
            minimumSize: const Size(100, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        ElevatedButton(
          onPressed: () => _giveFeedback(quiz, true),
          child: const Text('알겠음 😊', style: TextStyle(color: Colors.black)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromRGBO(196, 251, 199, 1),
            minimumSize: const Size(100, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _giveFeedback(Quiz quiz, bool isUnderstandingImproved) async {
    _logger.i(
        'Giving feedback: quizId=${quiz.id}, isUnderstandingImproved=$isUnderstandingImproved');
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
        _completedQuizIds.add(quiz.id); // Add completed quiz ID
        _currentQuizIndex = null;
      });

      // Logic to remove from review list remains
      if (isUnderstandingImproved) {
        await _userProvider.removeFromReviewList(
          _selectedSubjectId!,
          quiz.typeId,
          quiz.id,
        );
      }

      // _refreshQuizzes() method call removed
    } else {
      _logger.w('No user answer found for quiz: ${quiz.id}');
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
}
