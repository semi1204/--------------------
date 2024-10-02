import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';

class ErrorReportDialog extends StatefulWidget {
  final Quiz quiz;
  final String subjectId;
  final String quizTypeId;

  const ErrorReportDialog({
    super.key,
    required this.quiz,
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  _ErrorReportDialogState createState() => _ErrorReportDialogState();
}

class _ErrorReportDialogState extends State<ErrorReportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('문제 오류 보고'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: "오류 내용을 입력해주세요"),
        maxLines: 5,
      ),
      actions: <Widget>[
        TextButton.icon(
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('취소'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton.icon(
          icon: const Icon(Icons.send_outlined),
          label: const Text('보내기'),
          onPressed: () => _submitErrorReport(context),
        ),
      ],
    );
  }

  void _submitErrorReport(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('error_reports').add({
        'quizId': widget.quiz.id,
        'subjectId': widget.subjectId,
        'quizTypeId': widget.quizTypeId,
        'errorDescription': _controller.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류 보고가 성공적으로 제출되었습니다.')),
      );
    } catch (error) {
      print('Error submitting error report: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 보고를 제출할 수 없습니다: $error')),
      );
    }
    Navigator.of(context).pop();
  }
}
