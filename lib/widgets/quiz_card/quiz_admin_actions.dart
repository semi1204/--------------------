import 'package:flutter/material.dart';

class QuizAdminActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const QuizAdminActions({
    Key? key,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
