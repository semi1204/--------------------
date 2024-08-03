// widgets/add_dialog.dart
import 'package:flutter/material.dart';

class AddDialog extends StatelessWidget {
  final String itemType;

  const AddDialog({super.key, required this.itemType});

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return AlertDialog(
      title: Text('Add $itemType'),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: 'Enter $itemType name'),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              Navigator.of(context).pop(controller.text);
            }
          },
        ),
      ],
    );
  }
}
