// add_quiz_page.dart
import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/add_dialog.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/image_picker.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/image_upload.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/quiz_type_dropdown_with_add_button.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/keyword_fields.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_field.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import '../widgets/quiz_card/option_fields.dart';
import '../widgets/add_quiz/ox_toggle_button.dart';
import '../models/keyword.dart';

class AddQuizPage extends StatefulWidget {
  const AddQuizPage({super.key});

  @override
  State<AddQuizPage> createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<AddQuizPage> {
  final _formKey = GlobalKey<FormState>();
  late final Logger _logger;
  late final QuizService _quizService;
  String? _imageFile;

  String? _selectedSubjectId;
  String? _selectedTypeId;
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers =
      List.generate(5, (_) => TextEditingController());
  int _correctOptionIndex = 0;
  final TextEditingController _explanationController = TextEditingController();
  final List<TextEditingController> _keywordControllers = [
    TextEditingController()
  ];
  final TextEditingController _yearController =
      TextEditingController(); // year field
  String? _examType = 'CPA'; // CPA/CTA 선택을 위한 변수

  bool _isPreviewMode = false;
  bool _isOX = false; // OX Quiz Mode

  List<Keyword> _selectedKeywords = [];

  @override
  void initState() {
    super.initState();
    // Provider를 직접 초기화, post frame 콜백 사용 안 함
    _logger = Provider.of<Logger>(context, listen: false);
    _quizService = Provider.of<QuizService>(context, listen: false);
    _logger.i('AddQuizPage 초기화 완료');
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _explanationController.dispose();
    for (var controller in _keywordControllers) {
      controller.dispose();
    }
    _yearController.dispose(); // year field
    _logger.i('AddQuizPage 해제 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _logger.i('AddQuizPage 빌드 완료'); // 빌드 중 잠재적 setState를 방지하기 위해 주석 처리
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Quiz'),
        actions: [
          Switch(
            value: _isPreviewMode,
            onChanged: (value) {
              setState(() {
                _isPreviewMode = value;
              });
              _logger.i('미리보기 모드 변경: $_isPreviewMode');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UnifiedSubjectDropdown(
                selectedSubjectId: _selectedSubjectId,
                onSubjectSelected: _onSubjectSelected,
                onAddPressed: () => _showAddDialog(isSubject: true),
                showAddButton: true,
                useFormField: true,
              ),
              const SizedBox(height: 16),
              if (_selectedSubjectId != null)
                QuizTypeDropdownWithAddButton(
                  quizService: _quizService,
                  logger: _logger,
                  selectedSubjectId: _selectedSubjectId!,
                  selectedTypeId: _selectedTypeId,
                  onChanged: _onQuizTypeChanged,
                  onAddPressed: () => _showAddDialog(isSubject: false),
                  forceRefresh: true,
                ),
              const SizedBox(height: 16),
              KeywordFields(
                initialKeywords: _selectedKeywords,
                onKeywordsChanged: (keywords) {
                  setState(() {
                    _selectedKeywords = keywords;
                  });
                },
                logger: _logger,
              ),
              const SizedBox(height: 16),
              MarkdownField(
                controller: _questionController,
                labelText: 'Question',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a question' : null,
                isPreviewMode: _isPreviewMode,
                logger: _logger,
              ),
              const SizedBox(height: 16),
              ImagePickerWidget(
                imageFile: _imageFile,
                onImagePicked: (file) {
                  if (!mounted) return; // 안전장치
                  setState(() {
                    _imageFile = file;
                  });
                },
                logger: _logger,
              ),
              const SizedBox(height: 16),
              OXToggleButton(
                initialValue: _isOX,
                onChanged: (bool value) {
                  setState(() {
                    _isOX = value;
                    if (_isOX) {
                      _optionControllers.clear();
                      _optionControllers.addAll([
                        TextEditingController(text: 'O'),
                        TextEditingController(text: 'X')
                      ]);
                    } else {
                      _optionControllers.clear();
                      _optionControllers.addAll(
                        List.generate(5, (_) => TextEditingController()),
                      );
                    }
                    _correctOptionIndex = 0;
                  });
                  _logger.i('OX 퀴즈 모드 변경: $_isOX');
                },
              ),
              const SizedBox(height: 16),
              OptionFields(
                controllers: _optionControllers,
                correctOptionIndex: _correctOptionIndex,
                onOptionChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _correctOptionIndex = value;
                    });
                  }
                },
                logger: _logger,
                isOX: _isOX,
              ),
              const SizedBox(height: 16),
              MarkdownField(
                controller: _explanationController,
                labelText: 'Explanation',
                validator: (value) =>
                    value!.isEmpty ? 'Please enter an explanation' : null,
                isPreviewMode: _isPreviewMode,
                logger: _logger,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year (Optional)',
                  hintText: 'Enter the year of the quiz',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final year = int.tryParse(value);
                    if (year == null ||
                        year < 1900 ||
                        year > DateTime.now().year) {
                      return 'Please enter a valid year';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _examType,
                decoration: const InputDecoration(
                  labelText: 'Exam Type',
                ),
                items: ['CPA', 'CTA'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != _examType) {
                    setState(() {
                      _examType = newValue;
                    });
                  }
                },
                validator: (value) =>
                    value == null ? 'Please select an exam type' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitQuiz,
                child: const Text('Add Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSubjectSelected(String? newValue) {
    if (newValue != _selectedSubjectId) {
      // setState를 지연시키기 위해 addPostFrameCallback 사용
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedSubjectId = newValue;
            _selectedTypeId = null;
          });
        }
      });
      _logger.i('선택된 과목 변경: $newValue');
    }
  }

  void _onQuizTypeChanged(String? newValue) {
    if (newValue != _selectedTypeId) {
      // setState를 지연시키기 위해 addPostFrameCallback 사용
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedTypeId = newValue;
          });
        }
      });
      _logger.i('선택된 퀴즈 유형 변경: $newValue');
    }
  }

  Future<void> _showAddDialog({required bool isSubject}) async {
    final String itemType = isSubject ? '과목' : '퀴즈 유형';
    _logger.i('추가 $itemType 대화 상자 표시');

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AddDialog(itemType: itemType),
    );

    if (result != null && result.isNotEmpty) {
      if (isSubject) {
        await _quizService.addSubject(result);
        _logger.i('새 과목 추가: $result');
      } else if (_selectedSubjectId != null) {
        await _quizService.addQuizTypeToSubject(_selectedSubjectId!, result);
        _logger.i('새 퀴즈 유형 추가: $result to subject: $_selectedSubjectId');
      } else {
        _logger.w('과목을 선택하지 않고 퀴즈 유형을 추가하려고 함');
      }
      // 빌드 중 setState를 피하기 위해 다음 프레임으로 setState 지연
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {}); // 드롭다운 새로고침
        }
      });
    } else {
      _logger.w('빈 이름으로 $itemType 추가 시도');
    }
  }

  Future<void> _submitQuiz() async {
    _logger.i('퀴즈 제출 시도');
    if (_formKey.currentState!.validate()) {
      try {
        String? imageUrl;
        if (_imageFile != null) {
          imageUrl = await uploadImage(_imageFile!);
        }

        final newQuiz = Quiz(
          id: '',
          question: _questionController.text,
          options: _optionControllers.map((c) => c.text).toList(),
          correctOptionIndex: _correctOptionIndex,
          explanation: _explanationController.text,
          typeId: _selectedTypeId!,
          keywords: _selectedKeywords,
          imageUrl: imageUrl,
          year: _yearController.text.isNotEmpty
              ? int.parse(_yearController.text)
              : null,
          examType: _examType,
          isOX: _isOX,
        );
        await _quizService.addQuiz(
            _selectedSubjectId!, _selectedTypeId!, newQuiz);
        await _quizService.refreshSubjectData(_selectedSubjectId!);

        _logger.i('새 퀴즈 추가 성공: $imageUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('퀴즈 추가 성공')),
          );
          _resetForm();
        }
      } catch (e) {
        _logger.e('퀴즈 추가 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('퀴즈 추가 실패. 다시 시도해주세요.')),
          );
        }
      }
    } else {
      _logger.w('폼 검증 실패');
    }
  }

  void _resetForm() {
    _logger.i('폼 초기화');
    _formKey.currentState!.reset();
    _questionController.clear();
    for (var controller in _optionControllers) {
      controller.clear();
    }
    _explanationController.clear();
    for (var controller in _keywordControllers) {
      controller.dispose();
    }
    _keywordControllers.clear();
    _keywordControllers.add(TextEditingController());

    setState(() {
      _selectedSubjectId = null;
      _selectedTypeId = null;
      _correctOptionIndex = 0;
      _imageFile = null;
      _yearController.clear();
      _examType = 'CPA';
      _isOX = false;
      _selectedKeywords.clear();
    });
    _logger.i('폼 초기화 완료');
  }
}
