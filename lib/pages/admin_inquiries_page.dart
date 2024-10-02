import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/pages/edit_quiz_page.dart'; // 추가

class AdminInquiriesPage extends StatelessWidget {
  const AdminInquiriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 페이지'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '문의사항'),
              Tab(text: '오류 보고'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildInquiriesList(),
            _buildErrorReportsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiriesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inquiries')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['body']),
              subtitle: Text('From: ${data['userEmail'] ?? 'Anonymous'}'),
              trailing: Text(data['status']),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildErrorReportsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('error_reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            return ListTile(
              title: Text('Quiz ID: ${data['quizId']}'),
              subtitle: Text(data['errorDescription']),
              trailing: Text(data['status']),
              onTap: () => _showErrorReportDetails(context, data),
            );
          }).toList(),
        );
      },
    );
  }

  void _showErrorReportDetails(
      BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류 보고 상세'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quiz ID: ${data['quizId']}'),
              Text('Subject ID: ${data['subjectId']}'),
              Text('Quiz Type ID: ${data['quizTypeId']}'),
              Text('오류 설명: ${data['errorDescription']}'),
              Text('상태: ${data['status']}'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('닫기'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('수정하기'),
              onPressed: () => _editQuiz(context, data),
            ),
          ],
        );
      },
    );
  }

  void _editQuiz(BuildContext context, Map<String, dynamic> data) async {
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);

    // 기존 퀴즈 가져오기
    Quiz? existingQuiz = await quizProvider.getQuizById(
        data['subjectId'], data['quizTypeId'], data['quizId']);

    if (existingQuiz != null) {
      Navigator.of(context).pop(); // 현재 다이얼로그 닫기
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditQuizPage(
            quiz: existingQuiz,
            subjectId: data['subjectId'],
            quizTypeId: data['quizTypeId'],
          ),
        ),
      ).then((_) {
        // EditQuizPage에서 돌아왔을 때 오류 보고를 해결됨으로 표시
        FirebaseFirestore.instance
            .collection('error_reports')
            .doc(data['id'])
            .update({'status': 'resolved'});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈가 수정되었습니다.')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퀴즈를 찾을 수 없습니다.')),
      );
    }
  }
}
