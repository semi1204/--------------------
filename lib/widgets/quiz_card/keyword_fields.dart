import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/models/keyword.dart';
import 'package:nursing_quiz_app_6/services/keyword_service.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class KeywordFields extends StatefulWidget {
  final List<Keyword> initialKeywords;
  final Function(List<Keyword>) onKeywordsChanged;
  final Logger logger;

  const KeywordFields({
    super.key,
    required this.initialKeywords,
    required this.onKeywordsChanged,
    required this.logger,
  });

  @override
  State<KeywordFields> createState() => _KeywordFieldsState();
}

class _KeywordFieldsState extends State<KeywordFields> {
  final KeywordService _keywordService = KeywordService();
  final List<TextEditingController> _controllers = [];
  List<Keyword> _allKeywords = [];
  List<Keyword> _selectedKeywords = [];

  @override
  void initState() {
    super.initState();
    _loadKeywords();
    for (var keyword in widget.initialKeywords) {
      _addKeywordField(initialValue: keyword.content);
    }
    if (_controllers.isEmpty) {
      _addKeywordField();
    }
  }

  Future<void> _loadKeywords() async {
    try {
      final keywords = await _keywordService.getAllKeywords();
      if (mounted) {
        setState(() {
          _allKeywords = keywords;
        });
      }
    } catch (e) {
      widget.logger.e('Error loading keywords: $e');
    }
  }

  void _addKeywordField({String? initialValue}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _controllers.add(TextEditingController(text: initialValue));
        });
        widget.logger.i('Added new keyword field');
        _updateKeywords();
      }
    });
  }

  void _removeKeywordField(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _controllers[index].dispose();
          _controllers.removeAt(index);
        });
        widget.logger.i('Removed keyword field');
        _updateKeywords();
      }
    });
  }

  void _updateKeywords() {
    final keywords = _controllers
        .map((controller) {
          // 선택된 키워드가 있는지 확인
          final existingKeyword = _allKeywords.firstWhere(
            (k) => k.content == controller.text.trim(),
            orElse: () => Keyword(id: '', content: controller.text.trim()),
          );
          return existingKeyword;
        })
        .where((keyword) => keyword.content.isNotEmpty)
        .toList();

    widget.onKeywordsChanged(keywords);
  }

  List<Keyword> _getSuggestions(String query) {
    return _allKeywords
        .where((keyword) =>
            keyword.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keywords (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._controllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TypeAheadField<Keyword>(
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Enter a keyword',
                          border: OutlineInputBorder(),
                          prefixText: '#',
                        ),
                        onChanged: (value) => _updateKeywords(),
                      );
                    },
                    suggestionsCallback: (pattern) async {
                      if (pattern.startsWith('#')) {
                        pattern = pattern.substring(1);
                      }
                      return _getSuggestions(pattern);
                    },
                    itemBuilder: (context, Keyword suggestion) {
                      return ListTile(
                        title: Text(suggestion.content),
                      );
                    },
                    onSelected: (Keyword suggestion) {
                      controller.text = suggestion.content;
                      _updateKeywords();
                    },
                    emptyBuilder: (context) => const SizedBox.shrink(),
                    debounceDuration: const Duration(milliseconds: 300),
                    hideOnEmpty: true,
                    hideOnLoading: true,
                    hideOnError: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeKeywordField(index),
                ),
              ],
            ),
          );
        }),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Keyword'),
          onPressed: () => _addKeywordField(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleKeywordSelection(String content) async {
    try {
      final existingKeyword =
          await _keywordService.findKeywordByContent(content);
      if (existingKeyword != null) {
        // 기존 키워드 사용
        _updateSelectedKeywords(existingKeyword);
      } else {
        // 새 키워드 생성은 퀴즈 저장 시점으로 연기
        _updateSelectedKeywords(Keyword(id: '', content: content));
      }
    } catch (e) {
      widget.logger.e('Error handling keyword selection: $e');
    }
  }

  void _updateSelectedKeywords(Keyword keyword) {
    if (mounted) {
      setState(() {
        if (!_selectedKeywords.any((k) => k.content == keyword.content)) {
          _selectedKeywords.add(keyword);
          widget.onKeywordsChanged(_selectedKeywords);
        }
      });
    }
  }
}
