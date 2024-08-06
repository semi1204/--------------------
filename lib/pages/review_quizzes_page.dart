import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/common_widgets.dart';
import 'package:nursing_quiz_app_6/widgets/review_quiz/subject_dropdown.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';
import '../models/subject.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math' show min;
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
  bool _isOffline = false;
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
      final quizTypes = await _quizService.getQuizTypes(_selectedSubjectId!);
      List<Quiz> allQuizzesForReview = [];

      for (var quizType in quizTypes) {
        final quizzesForReview = await _quizService.getQuizzesForReview(
            _userProvider.user!.uid, _selectedSubjectId!, quizType.id);
        allQuizzesForReview.addAll(quizzesForReview);
      }

      _logger.i('복습할 퀴즈 ${allQuizzesForReview.length}개를 찾았습니다');

      if (mounted) {
        setState(() {
          _quizzesForReview = allQuizzesForReview;
          _isLoading = false;
        });
      }
      if (_quizzesForReview.isEmpty) {
        _logger.w('No quizzes available for review');
        ScaffoldMessenger.of(context).showSnackBar(
          CommonSnackBar(message: '현재 복습할 퀴즈가 없어요! 나중에 다시 확인해주세요~'),
        );
      }
    } catch (e) {
      _logger.e('Error loading quizzes for review: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading quizzes for review. Please try again.';
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
    await _loadQuizzesForReview();
  }

  Widget _buildQuizList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_quizzesForReview.isEmpty) {
      return const Center(child: Text('No quizzes for review available'));
    }
    return ListView.builder(
      itemCount: _quizzesForReview.length,
      itemBuilder: (context, index) {
        final quiz = _quizzesForReview[index];
        _logger.d('퀴즈 카드 빌드 중: ${quiz.id}');
        return QuizCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          isAdmin: _userProvider.isAdmin,
          questionNumber: index + 1,
          onAnswerSelected: (answerIndex) {
            _logger.i(
                'Answer selected for quiz: ${quiz.id}, answer: $answerIndex');
            setState(() {}); // Refresh UI when answer is selected
          },
          onDeleteReview: () => _deleteReview(quiz),
          subjectId: _selectedSubjectId!,
          quizTypeId: quiz.typeId,
          nextReviewDate: _userProvider
              .getNextReviewDate(
                _selectedSubjectId!,
                quiz.typeId,
                quiz.id,
              )
              .toIso8601String(),
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
