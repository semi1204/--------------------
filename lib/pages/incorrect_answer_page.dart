import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:logger/logger.dart';

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
  int _currentQuizIndex = 0;
  int? _selectedOptionIndex;
  List<Quiz> _incorrectQuizzes = [];

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('IncorrectAnswersPage initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 수정: AppBar 제거
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSubjectDropdown(),
            Expanded(
              child: _selectedSubjectId == null
                  ? const Center(child: Text('Please select a subject'))
                  : _buildQuizContent(),
            ),
          ],
        ),
      ),
    );
  }

  // 추가: 헤더 위젯
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Incorrect Answers',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAlgorithmInfo,
          ),
        ],
      ),
    );
  }

  // 추가: 알고리즘 정보 표시 함수
  void _showAlgorithmInfo() {
    _logger.i('Showing algorithm info');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Anki Algorithm 🧠'),
          content: const SingleChildScrollView(
            child: Text(
              '이 앱은 Anki 알고리즘을 사용해요! 🌟\n\n'
              '1. 문제를 맞추면 복습 간격이 늘어나요 📈\n'
              '2. 틀리면 간격이 줄어들어요 📉\n'
              '3. 빨리 답하면 더 긴 간격이 주어져요 ⏱️\n'
              '4. 여러분의 학습 패턴에 맞춰 최적화돼요 🎯\n\n'
              '열심히 공부하면 효율적으로 배울 수 있어요! 화이팅! 💪😊',
              style: TextStyle(fontSize: 16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('알겠어요! 👍'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<List<Subject>>(
        stream: _quizService.getSubjects(),
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
                _currentQuizIndex = 0;
              });
              _logger.i('Selected subject: $newValue');
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
      ),
    );
  }

  Widget _buildQuizContent() {
    return StreamBuilder<List<Quiz>>(
      stream: _userProvider.user != null
          ? _quizService.getIncorrectQuizzes(
              _userProvider.user!.uid, _selectedSubjectId!)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No incorrect quizzes available'));
        }
        _incorrectQuizzes = snapshot.data!;
        _logger
            .i('Incorrect quizzes loaded. Count: ${_incorrectQuizzes.length}');

        return Column(
          children: [
            Expanded(
              child: QuizCard(
                quiz: _incorrectQuizzes[_currentQuizIndex],
                questionNumber: _currentQuizIndex + 1,
                selectedOptionIndex: _selectedOptionIndex,
                onAnswerSelected: _onAnswerSelected,
                isIncorrectAnswersMode: true,
                isScrollable: true,
                onDeleteReview: () =>
                    _deleteReview(_incorrectQuizzes[_currentQuizIndex]),
              ),
            ),
            _buildNavigationButtons(_incorrectQuizzes.length),
          ],
        );
      },
    );
  }

  Future<void> _deleteReview(Quiz quiz) async {
    _logger.i('Deleting review for quiz: ${quiz.id}');
    try {
      await _userProvider.deleteUserQuizData(_userProvider.user!.uid, quiz.id);
      _logger.i('Review deleted successfully');
      if (mounted) {
        setState(() {
          _incorrectQuizzes.removeWhere((q) => q.id == quiz.id);
          if (_currentQuizIndex >= _incorrectQuizzes.length) {
            _currentQuizIndex =
                _incorrectQuizzes.isEmpty ? 0 : _incorrectQuizzes.length - 1;
          }
        });
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

  void _onAnswerSelected(int index) {
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  Widget _buildNavigationButtons(int quizCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _currentQuizIndex > 0 ? _previousQuestion : null,
          child: const Text('Previous'),
        ),
        Text('${_currentQuizIndex + 1} / $quizCount'),
        ElevatedButton(
          onPressed:
              _selectedOptionIndex != null && _currentQuizIndex < quizCount - 1
                  ? _nextQuestion
                  : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  void _previousQuestion() {
    if (_currentQuizIndex > 0) {
      setState(() {
        _currentQuizIndex--;
        _selectedOptionIndex = null;
      });
    }
  }

  void _nextQuestion() {
    setState(() {
      _currentQuizIndex++;
      _selectedOptionIndex = null;
    });
  }
}
