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

        return Row(
          // 우측: 정답률과 초기화 버튼
          // DONE : 정답률 표시와 Row를 이루는 왼쪽에 빨색, 노란색, 초록색, 으로 작은 원으로 불빛이 들어오게 함.정답률이 85% 이상이면 초록색, 60% 이상이면 노란색, 60% 미만이면 빨간색으로 표시
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getExamInfo(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (questionNumber != null) ...[
              Text(
                '$questionNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            Row(
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Ionicons.ellipsis_vertical, size: 20),
                  onPressed: () => _showQuizMenu(context),
                  tooltip: 'Quiz Menu',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --------- DONE : 퀴즈 초기화 버튼 클릭 시 데이터 이동확인 ---------//

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
