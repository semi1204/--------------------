import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import 'dart:async'; // Timer를 사용하기 위해 추가
import '../widgets/close_button.dart'; // 커스텀 CloseButton import

class QuizPage extends StatefulWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({
    super.key,
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  List<Quiz> _quizzes = [];
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();
  int _lastScrollIndex = 0;
  final Map<String, int?> _selectedAnswers = {};
  bool _rebuildExplanation = false;
  bool _isAppBarVisible = true;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _loadQuizzesAndSetInitialScroll();
    _positionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onScroll);
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 100), () {
      if (_positionsListener.itemPositions.value.isNotEmpty) {
        final firstVisibleItemIndex =
            _positionsListener.itemPositions.value.first.index;
        if (firstVisibleItemIndex != _lastScrollIndex) {
          final isScrollingUp = firstVisibleItemIndex < _lastScrollIndex;
          setState(() {
            _isAppBarVisible = isScrollingUp;
            _lastScrollIndex = firstVisibleItemIndex;
          });
          _logger
              .i('Scroll direction changed. AppBar visible: $_isAppBarVisible');
        }
      }
    });
  }

  Future<void> _loadQuizzesAndSetInitialScroll() async {
    _logger.i('퀴즈 로딩 및 초기 스크롤 위치 설정 시작');
    try {
      final quizzes =
          await _quizService.getQuizzes(widget.subjectId, widget.quizTypeId);
      if (mounted) {
        setState(() {
          _quizzes = quizzes;
          _lastScrollIndex = _findLastAnsweredQuizIndex();
          _loadSavedAnswers();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_lastScrollIndex > 0 && _scrollController.isAttached) {
            _scrollController.scrollTo(
              index: _lastScrollIndex,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      _logger.i(
          'Loaded ${_quizzes.length} quizzes, initial scroll index: $_lastScrollIndex');
    } catch (e) {
      _logger.e('Error loading quizzes: $e');
    }
  }

  // 추가: 저장된 사용자 답변 로드 메서드
  void _loadSavedAnswers() {
    final userData = _userProvider.getUserQuizData();
    for (var quiz in _quizzes) {
      final quizData = userData[widget.subjectId]?[widget.quizTypeId]?[quiz.id];
      if (quizData != null && quizData is Map<String, dynamic>) {
        _selectedAnswers[quiz.id] = quizData['selectedOptionIndex'] as int?;
      }
    }
  }

  int _findLastAnsweredQuizIndex() {
    final userData = _userProvider.getUserQuizData();
    for (int i = _quizzes.length - 1; i >= 0; i--) {
      final quizData =
          userData[widget.subjectId]?[widget.quizTypeId]?[_quizzes[i].id];
      if (quizData != null &&
          quizData is Map<String, dynamic> &&
          quizData['selectedOptionIndex'] != null) {
        return i + 1; // 마지막으로 답변한 퀴즈의 다음 인덱스 반환
      }
    }
    return 0; // 모든 퀴즈가 미답변 상태일 경우
  }

// 수정 시 주의 사항
// 1. QuizCard 위젯에서 User의 기존 선택지는 항상 표시되어있어야함.
// 2. User는 초기화 버튼으로만 선택지를 초기화할 수 있어야함.
// 3. User가 선택지를 변경하면, QuizCard 위젯은 즉시 변경된 선택지를 표시해야함.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return _quizzes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      pinned: false,
                      title: const Text('Quiz'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: const [
                        CustomCloseButton()
                      ], // CustomCloseButton 사용
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                        child: ScrollablePositionedList.builder(
                          itemCount: _quizzes.length,
                          itemScrollController: _scrollController,
                          itemPositionsListener: _positionsListener,
                          itemBuilder: (context, index) {
                            final quiz = _quizzes[index];
                            final selectedAnswer =
                                _selectedAnswers[quiz.id]; // 수정: 저장 답변 사용
                            _logger.i(
                                'Quiz ${quiz.id} - Selected answer: $selectedAnswer');
                            return QuizPageCard(
                              key: ValueKey(quiz.id),
                              quiz: quiz,
                              questionNumber: index + 1,
                              isAdmin: userProvider.isAdmin,
                              onEdit: () => _editQuiz(quiz),
                              onDelete: () => _deleteQuiz(quiz),
                              // 선택된 답은 updateUserQuizData 에 저장됨
                              onAnswerSelected: (answerIndex) {
                                _logger.i(
                                    'Answer selected for quiz: ${quiz.id}, answer: $answerIndex');
                                setState(() {
                                  _selectedAnswers[quiz.id] =
                                      answerIndex; // 선택된 답변 업데이트
                                });
                                userProvider.updateUserQuizData(
                                  widget.subjectId,
                                  widget.quizTypeId,
                                  quiz.id,
                                  answerIndex == quiz.correctOptionIndex,
                                  selectedOptionIndex: answerIndex,
                                );
                              },
                              onResetQuiz: () {
                                setState(() {
                                  _selectedAnswers[quiz.id] = null;
                                  _rebuildExplanation = !_rebuildExplanation;
                                });
                              },
                              subjectId: widget.subjectId,
                              quizTypeId: widget.quizTypeId,
                              selectedOptionIndex:
                                  selectedAnswer, // 수정: 저장된 답변 사용
                              isQuizPage: true, // 추가: isQuizPage 매개변수
                              nextReviewDate: userProvider
                                      .getNextReviewDate(
                                        widget.subjectId, // 위젯속성으로 고정된 값임
                                        widget.quizTypeId,
                                        quiz.id,
                                      )
                                      ?.toIso8601String() ??
                                  DateTime.now().toIso8601String(),
                              rebuildExplanation:
                                  _rebuildExplanation, // 추가: QuizExplanation 위젯 리빌드 트리거
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }

  void _editQuiz(Quiz quiz) {
    _logger.i('Editing quiz: ${quiz.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: widget.subjectId,
          quizTypeId: widget.quizTypeId,
        ),
      ),
    );
  }

  void _deleteQuiz(Quiz quiz) {
    _logger.i('Deleting quiz: ${quiz.id}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text('Are you sure you want to delete this quiz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await _quizService.deleteQuiz(
                    widget.subjectId, widget.quizTypeId, quiz.id);
                setState(() {
                  _quizzes.removeWhere((q) => q.id == quiz.id);
                });
                Navigator.of(context).pop();
                _logger.i('Quiz deleted: ${quiz.id}');
              },
            ),
          ],
        );
      },
    );
  }
}
