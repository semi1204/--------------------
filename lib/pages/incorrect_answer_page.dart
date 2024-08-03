import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';
import '../models/subject.dart';

class IncorrectAnswersPage extends StatefulWidget {
  const IncorrectAnswersPage({super.key});

  @override
  State<IncorrectAnswersPage> createState() => _IncorrectAnswersPageState();
}

class _IncorrectAnswersPageState extends State<IncorrectAnswersPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  String? _selectedSubjectId;
  List<Quiz> _incorrectQuizzes = [];

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('IncorrectAnswersPage initialized');
  }

  Future<void> _loadIncorrectQuizzes() async {
    if (_selectedSubjectId == null) return;
    _logger.i('Loading incorrect quizzes for subject: $_selectedSubjectId');
    try {
      // 수정: getIncorrectQuizzes 메서드 호출 방식 변경
      final quizzes = await _quizService.getIncorrectQuizzes(
        _userProvider.user!.uid,
        _selectedSubjectId!,
      );
      if (mounted) {
        setState(() {
          _incorrectQuizzes = quizzes;
        });
      }
      _logger.i('Loaded ${_incorrectQuizzes.length} incorrect quizzes');
    } catch (e) {
      _logger.e('Error loading incorrect quizzes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Cards!'),
      ),
      body: Column(
        children: [
          _buildSubjectDropdown(),
          Expanded(
            child: _selectedSubjectId == null
                ? const Center(child: Text('Please select a subject'))
                : _buildQuizList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return FutureBuilder<List<Subject>>(
      future: _quizService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No subjects available');
        }
        return DropdownButton<String>(
          value: _selectedSubjectId,
          hint: const Text('Select a subject'),
          onChanged: (String? newValue) {
            setState(() {
              _selectedSubjectId = newValue;
              _incorrectQuizzes = [];
            });
            _loadIncorrectQuizzes();
          },
          items:
              snapshot.data!.map<DropdownMenuItem<String>>((Subject subject) {
            return DropdownMenuItem<String>(
              value: subject.id,
              child: Text(subject.name),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuizList() {
    if (_incorrectQuizzes.isEmpty) {
      return const Center(child: Text('No incorrect quizzes available'));
    }
    return ListView.builder(
      itemCount: _incorrectQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = _incorrectQuizzes[index];
        return QuizCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          questionNumber: index + 1,
          isIncorrectAnswersMode: true,
          onAnswerSelected: (answerIndex) {
            setState(() {}); // 답변 선택 시 UI 갱신
          },
          onDeleteReview: () => _deleteReview(quiz),
          subjectId: _selectedSubjectId!,
          quizTypeId: quiz.typeId,
        );
      },
    );
  }

// 수정시 주의 사항:
// deletereview 버튼의 역할 :=> incorrectquizpage에서 카드를 삭제함.
//기기내부와 서버에서 reviewlist에서 삭제됨.
//quizlist와는 무관하고,
//quizpage에서 사용자가 기존에 선택한 ui는 변하지 않음.
  Future<void> _deleteReview(Quiz quiz) async {
    _logger.i('Deleting review for quiz: ${quiz.id}');
    try {
      // 수정: deleteUserQuizData 메서드 호출 수정
      await _userProvider.deleteUserQuizData(
        _userProvider.user!.uid,
        _selectedSubjectId!,
        quiz.typeId,
        quiz.id,
      );
      setState(() {
        _incorrectQuizzes.removeWhere((q) => q.id == quiz.id);
      });
      _logger.i('Review deleted successfully');

      // 수정: 사용자에게 피드백 제공
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully')),
      );
    } catch (e) {
      _logger.e('Error deleting review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to delete review. Please try again.')),
      );
    }
  }
}
