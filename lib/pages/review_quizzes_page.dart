import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/common_widgets.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('ReviewQuizzesPage initialized');
    _logLocalData();
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

  Future<void> _loadQuizzesForReview() async {
    _logger.i('_loadQuizzesForReview 시작');
    _logger.d('선택된 과목: $_selectedSubjectId'); // 복습은 과목 단위로 이루어짐

    if (_selectedSubjectId == null) {
      _logger.w('과목이 선택되지 않았습니다');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 퀴즈 타입을 가져오고, 모든 퀴즈를 한 번에 로드합니다.
      final quizTypes = await _quizService.getQuizTypes(_selectedSubjectId!);
      final quizTypeIds = quizTypes.map((type) => type.id).toList();
      final quizzesForReview = await _quizService.getQuizzesForReview(
        _userProvider.user!.uid,
        _selectedSubjectId!,
        quizTypeIds.join('_'), // join을 사용해서 subject의 하위 데이터인 tpye을 한번에 가져옴
      );

      _logger.i('복습할 퀴즈 ${quizzesForReview.length}개를 찾았습니다');

      if (mounted) {
        setState(() {
          _quizzesForReview = quizzesForReview;
          _isLoading = false;
        });
      }

      if (_quizzesForReview.isEmpty) {
        _logger.w('복습할 퀴즈가 없습니다');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            CommonSnackBar(message: '현재 복습할 퀴즈가 없어요! 나중에 다시 확인해주세요~'),
          );
        }
      }
    } catch (e) {
      _logger.e('복습할 퀴즈 로딩 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '복습할 퀴즈를 불러오는 중 오류가 발생했습니다. 다시 시도해 주세요.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          CommonSnackBar(message: '복습할 퀴즈를 불러오는 중 오류가 발생했어요! 😢 다시 시도해 주세요~ '),
        );
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

    final quizzesToReview = _quizzesForReview.where((quiz) {
      final nextReviewTime = _userProvider.getNextReviewTimeString(
        _selectedSubjectId!,
        quiz.typeId,
        quiz.id,
      );
      return nextReviewTime == '지금';
    }).toList();

    if (quizzesToReview.isEmpty) {
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
      itemCount: quizzesToReview.length,
      itemBuilder: (context, index) {
        final quiz = quizzesToReview[index];
        final nextReviewTime = _userProvider.getNextReviewTimeString(
          _selectedSubjectId!,
          quiz.typeId,
          quiz.id,
        );
        _logger.d('Quiz ${quiz.id} next review time: $nextReviewTime');
        if (nextReviewTime != '지금') {
          _logger.d('Quiz ${quiz.id} skipped: next review time is not now');
          return Container(); // 리뷰 시간이 되지 않은 퀴즈는 표시하지 않음
        }
        _logger.d('Building QuizCard for quiz ${quiz.id}');

        // 안전한 날짜 문자열 생성
        String safeNextReviewDate;
        try {
          final nextReviewDate = _userProvider.getNextReviewDate(
            _selectedSubjectId!,
            quiz.typeId,
            quiz.id,
          );
          safeNextReviewDate = nextReviewDate?.toIso8601String() ??
              DateTime.now().toIso8601String();
        } catch (e) {
          _logger.e('Error getting next review date for quiz ${quiz.id}: $e');
          safeNextReviewDate = DateTime.now().toIso8601String();
        }

        return QuizCard(
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

            await _refreshQuizzes(); // 퀴즈 리스트 새로고침
          },
          onDeleteReview: () => _deleteReview(quiz),
          subjectId: _selectedSubjectId!,
          quizTypeId: quiz.typeId,
          nextReviewDate: safeNextReviewDate,
          isQuizPage: false,
          selectedOptionIndex: null,
        );
      },
    );
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
