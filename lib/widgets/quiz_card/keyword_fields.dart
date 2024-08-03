import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class KeywordFields extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Logger logger;

  const KeywordFields({
    super.key,
    required this.controllers,
    required this.logger,
  });

  @override
  State<KeywordFields> createState() => _KeywordFieldsState();
}

class _KeywordFieldsState extends State<KeywordFields> {
  void _removeKeywordField(TextEditingController controller) {
    setState(() {
      widget.controllers.remove(controller);
      controller.dispose();
    });
    widget.logger.i('Removed keyword field');
  }

  void _addKeywordField() {
    setState(() {
      widget.controllers.add(TextEditingController());
    });
    widget.logger.i('Added new keyword field');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keywords (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.controllers.map((controller) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter a keyword',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeKeywordField(controller),
                  ),
                ],
              ),
            )),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Keyword'),
          onPressed: _addKeywordField,
        ),
      ],
    );
  }
}
