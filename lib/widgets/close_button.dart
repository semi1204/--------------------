import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/providers/subject_provider.dart';

// 버튼을 클릭하면 subjectPage로 이동해야함. subjectPage에서 naviationBar로 과목, 복습, 퀴즈추가로 이동할 수 있음.
class CustomCloseButton extends StatelessWidget {
  const CustomCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Provider.of<Logger>(context, listen: false);
    final subjectProvider =
        Provider.of<SubjectProvider>(context, listen: false);

    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        logger.i('Close button pressed');
        // Navigate to the SubjectPage and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SubjectPage()),
          (Route<dynamic> route) => false,
        );
        // Reset the selected index to 0 (과목 탭)
        subjectProvider.setSelectedIndex(0);
      },
    );
  }
}
