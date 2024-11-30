import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/accuracy_display.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:ionicons/ionicons.dart';
import '../../widgets/font_size_adjuster.dart'; // Import the new widget

class QuizHeader extends StatelessWidget {
  final Quiz quiz;
  final String subjectId;
  final String quizTypeId;
  final VoidCallback onResetQuiz;
  final VoidCallback onReportError;
  final Logger logger;
  final int? questionNumber;

  const QuizHeader({
    super.key,
    required this.quiz,
    required this.subjectId,
    required this.quizTypeId,
    required this.onResetQuiz,
    required this.onReportError,
    required this.logger,
    this.questionNumber,
  });

  // 각 퀴즈ID에 대한 메뉴화면
  void _showQuizMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('선택 취소'),
                onTap: () {
                  Navigator.pop(context);
                  _resetSelectedOption(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem),
                title: const Text('문제 오류 보고'),
                onTap: () {
                  Navigator.pop(context);
                  onReportError();
                },
              ),
              // Add Font Size Adjustment menu item
              ListTile(
                leading: const Icon(Icons.font_download),
                title: const Text('글자 크기 조정'),
                onTap: () {
                  Navigator.pop(context);
                  logger.i('Navigating to Font Size Adjuster from Quiz Menu');
                  showDialog(
                    context: context,
                    builder: (context) => FontSizeAdjuster(logger: logger),
                  );
                },
              ),
              // Add more menu items as needed
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetSelectedOption(BuildContext context) async {
    try {
      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      await quizProvider.resetSelectedOption(subjectId, quizTypeId, quiz.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택이 취소되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.e('Error in _resetSelectedOption: $e');
    }
  }

  // 문제의 가장 상단엔, 기출, accuracy, reset button이 Row로 표시
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, QuizProvider>(
      builder: (context, userProvider, quizProvider, child) {
        final accuracy = userProvider.getQuizAccuracy(
          subjectId,
          quizTypeId,
          quiz.id,
        );
        logger.d('퀴즈 정답률: $accuracy');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 문제 번호와 기출 정보를 포함하는 왼쪽 섹션
              Expanded(
                child: Row(
                  children: [
                    if (questionNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '$questionNumber번',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    if (questionNumber != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 20,
                        width: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getExamInfo(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 정확도와 메뉴 버튼
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 정확도 표시
                  GestureDetector(
                    onTap: () {
                      final quizProvider =
                          Provider.of<QuizProvider>(context, listen: false);
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => AccuracyFilterBottomSheet(),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getAccuracyColor(accuracy),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AccuracyDisplay(accuracy: accuracy),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 메뉴 버튼
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showQuizMenu(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Ionicons.ellipsis_horizontal,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getExamInfo() {
    String examInfo = '';
    if (quiz.year != null) {
      examInfo += '${quiz.year} ';
    }
    if (quiz.examType != null && quiz.examType!.isNotEmpty) {
      examInfo += quiz.examType!;
    }
    return examInfo.isNotEmpty ? examInfo : '기출문제';
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.85) {
      return Colors.green;
    } else if (accuracy >= 0.60) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }
}

class AccuracyFilterBottomSheet extends StatelessWidget {
  const AccuracyFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 16),
            child: Text(
              '정답률로 필터링',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('전체 보기'),
            selected: quizProvider.currentSortOption == SortOption.all,
            onTap: () {
              quizProvider.setSortOption(SortOption.all);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
            ),
            title: const Text('20% 미만'),
            selected: quizProvider.currentSortOption == SortOption.low,
            onTap: () {
              quizProvider.setSortOption(SortOption.low);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.yellow,
              ),
            ),
            title: const Text('20% ~ 60%'),
            selected: quizProvider.currentSortOption == SortOption.medium,
            onTap: () {
              quizProvider.setSortOption(SortOption.medium);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
            ),
            title: const Text('60% 이상'),
            selected: quizProvider.currentSortOption == SortOption.high,
            onTap: () {
              quizProvider.setSortOption(SortOption.high);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
