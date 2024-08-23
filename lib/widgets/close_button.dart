import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';

class CloseButton extends StatelessWidget {
  const CloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Provider.of<Logger>(context, listen: false);

    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        logger.i('Close button pressed');
        // Navigate to the SubjectPage and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          // TODO : 과목페이지로 이동하지 못하고 있음.
          // subjectPage가 DraggablePage 내의 탭으로 존재하기 때문에 이동이 안되는 것으로 보임.
          // 이를 해결하기 위해서는 subjectPage를 별도의 페이지로 분리해야함.
          MaterialPageRoute(builder: (context) => SubjectPage()),
          (Route<dynamic> route) => false,
        );
      },
    );
  }
}
