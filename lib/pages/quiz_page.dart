import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz_type.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import '../providers/theme_provider.dart';
import '../widgets/close_button.dart';
import '../widgets/linked_title.dart';
import '../utils/constants.dart';
import '../providers/quiz_view_mode_provider.dart';
import '../widgets/add_quiz/ox_toggle_button.dart';

class QuizPage extends StatefulWidget {
  final Subject subject;
  final QuizType quizType;

  const QuizPage({
    super.key,
    required this.subject,
    required this.quizType,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  final AutoScrollController _scrollController = AutoScrollController();
  bool _isDisposed = false; // 추가

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quizProvider = context.read<QuizProvider>();
      final viewModeProvider = context.read<QuizViewModeProvider>();

      // Set selected subject and quiz type IDs
      quizProvider.setSelectedSubjectId(widget.subject.id);
      quizProvider.setSelectedQuizTypeId(widget.quizType.id);
      // Check if the quiz type is OX and set the toggle accordingly
      bool isOXQuiz = widget.quizType.id ==
          'ox_quiz_type_id'; // Replace with your actual OX quiz type ID
      quizProvider.toggleQuizType(isOXQuiz);

      // Load quizzes and set initial scroll
      await quizProvider.loadQuizzesAndSetInitialScroll(
        widget.subject.id,
        widget.quizType.id,
      );
      final initialIndex = quizProvider.lastScrollIndex;

      // Set initial index for both view modes
      viewModeProvider.setCurrentIndex(initialIndex);

      // Scroll to the initial index
      await _scrollController.scrollToIndex(
        initialIndex,
        preferPosition: AutoScrollPosition.begin,
      );

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          context.read<QuizProvider>().resetSortOption();
        }
      },
      child: Scaffold(
        body: Consumer3<QuizProvider, UserProvider, ThemeProvider>(
          builder: (context, quizProvider, userProvider, themeProvider, child) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  title: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: LinkedTitle(
                      titles: [widget.subject.name, widget.quizType.name],
                      onTap: (index) {
                        if (index == 0) {
                          // Navigate to SubjectPage
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const SubjectPage(),
                            ),
                          );
                        } else if (index == 1) {
                          // Navigate back to QuizTypePage
                          Navigator.of(context).pop();
                        }
                        // Reset sort option when navigating
                        quizProvider.resetSortOption();
                      },
                      textStyle: getAppTextStyle(context, fontSize: 16),
                    ),
                  ),
                  floating: true,
                  snap: true,
                  pinned: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.sort),
                      onPressed: () => _showFilterDialog(context, quizProvider),
                    ),
                    IconButton(
                      icon: Icon(
                        context.select((QuizViewModeProvider p) => p.isOneByOne)
                            ? Icons.view_agenda
                            : Icons.view_list,
                      ),
                      onPressed: () =>
                          context.read<QuizViewModeProvider>().toggleViewMode(),
                    ),
                    OXToggleButton(
                      initialValue: quizProvider.showOXOnly,
                      onChanged: (value) {
                        quizProvider.toggleQuizType(value);
                      },
                    ),
                    const CustomCloseButton(),
                  ],
                ),
                if (quizProvider.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (quizProvider.quizzes.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        quizProvider.isFilterEmpty
                            ? '선택한 필터에 해당하는 퀴즈가 없습니다.'
                            : '퀴즈를 불러오는 중입니다',
                        style: getAppTextStyle(context, fontSize: 16),
                      ),
                    ),
                  )
                else
                  Consumer<QuizViewModeProvider>(
                    builder: (context, viewMode, child) {
                      return viewMode.isOneByOne
                          ? _buildOneByOneView(
                              quizProvider, userProvider, viewMode)
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final quiz = quizProvider.quizzes[index];
                                  return AutoScrollTag(
                                    key: ObjectKey('${quiz.id}_$index'),
                                    controller: _scrollController,
                                    index: index,
                                    child: QuizPageCard(
                                      key: ObjectKey(quiz.id),
                                      quiz: quiz,
                                      questionNumber: index + 1,
                                      isAdmin: userProvider.isAdmin,
                                      onEdit: () => _editQuiz(quiz),
                                      onDelete: () => _deleteQuiz(quiz),
                                      onAnswerSelected: (answerIndex) =>
                                          _selectAnswer(quizProvider, quiz.id,
                                              answerIndex),
                                      onResetQuiz: () =>
                                          _resetQuiz(quizProvider, quiz.id),
                                      subjectId: widget.subject.id,
                                      quizTypeId: widget.quizType.id,
                                      selectedOptionIndex:
                                          quizProvider.selectedAnswers[quiz.id],
                                      isQuizPage: true,
                                      nextReviewDate: userProvider
                                              .getNextReviewDate(
                                                widget.subject.id,
                                                widget.quizType.id,
                                                quiz.id,
                                              )
                                              ?.toIso8601String() ??
                                          DateTime.now().toIso8601String(),
                                      rebuildExplanation:
                                          quizProvider.rebuildExplanation,
                                    ),
                                  );
                                },
                                childCount: quizProvider.quizzes.length,
                              ),
                            );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, QuizProvider quizProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('카드 필터'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('모든 카드'),
                value: SortOption.all,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('빨간색 카드 (60% 미만)'),
                value: SortOption.low,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('노란색 카드 (60% - 85%)'),
                value: SortOption.medium,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('초록색 카드 (85% 이상)'),
                value: SortOption.high,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectAnswer(
      QuizProvider quizProvider, String quizId, int answerIndex) {
    quizProvider.selectAnswer(
      widget.subject.id,
      widget.quizType.id,
      quizId,
      answerIndex,
    );
    quizProvider.updateQuizAccuracy(
        widget.subject.id, widget.quizType.id, quizId);
  }

  void _resetQuiz(QuizProvider quizProvider, String quizId) {
    quizProvider.resetSelectedOption(
        widget.subject.id, widget.quizType.id, quizId);
    quizProvider.updateQuizAccuracy(
        widget.subject.id, widget.quizType.id, quizId);
  }

  void _editQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: widget.subject.id,
          quizTypeId: widget.quizType.id,
        ),
      ),
    );
  }

  void _deleteQuiz(Quiz quiz) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text('정말로 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                final quizProvider = context.read<QuizProvider>();
                await quizProvider.deleteQuiz(
                    widget.subject.id, widget.quizType.id, quiz.id);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true; // 추가
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _safeSetState(VoidCallback fn) async {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Widget _buildOneByOneView(QuizProvider quizProvider,
      UserProvider userProvider, QuizViewModeProvider viewMode) {
    if (quizProvider.quizzes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    final currentQuiz = quizProvider.quizzes[viewMode.currentIndex];
    final isLastQuiz = viewMode.currentIndex == quizProvider.quizzes.length - 1;

    return SliverList(
      delegate: SliverChildListDelegate([
        AutoScrollTag(
          key: ObjectKey('${currentQuiz.id}_${viewMode.currentIndex}'),
          controller: _scrollController,
          index: viewMode.currentIndex,
          child: Column(
            children: [
              QuizPageCard(
                key: ObjectKey(currentQuiz.id),
                quiz: currentQuiz,
                questionNumber: viewMode.currentIndex + 1,
                isAdmin: userProvider.isAdmin,
                onEdit: () => _editQuiz(currentQuiz),
                onDelete: () => _deleteQuiz(currentQuiz),
                onAnswerSelected: (answerIndex) =>
                    _selectAnswer(quizProvider, currentQuiz.id, answerIndex),
                onResetQuiz: () => _resetQuiz(quizProvider, currentQuiz.id),
                subjectId: widget.subject.id,
                quizTypeId: widget.quizType.id,
                selectedOptionIndex:
                    quizProvider.selectedAnswers[currentQuiz.id],
                isQuizPage: true,
                nextReviewDate: userProvider
                        .getNextReviewDate(
                          widget.subject.id,
                          widget.quizType.id,
                          currentQuiz.id,
                        )
                        ?.toIso8601String() ??
                    DateTime.now().toIso8601String(),
                rebuildExplanation: quizProvider.rebuildExplanation,
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: viewMode.currentIndex > 0
                          ? () async {
                              viewMode.previousQuiz();
                              if (mounted) {
                                await _scrollController.scrollToIndex(
                                  viewMode.currentIndex,
                                  preferPosition: AutoScrollPosition.begin,
                                );
                              }
                            }
                          : null,
                    ),
                    Text(
                        '${viewMode.currentIndex + 1}/${quizProvider.quizzes.length}'),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: !isLastQuiz
                          ? () async {
                              viewMode.nextQuiz();
                              if (mounted) {
                                await _scrollController.scrollToIndex(
                                  viewMode.currentIndex,
                                  preferPosition: AutoScrollPosition.begin,
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
