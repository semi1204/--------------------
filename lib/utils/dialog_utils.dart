import 'package:flutter/material.dart';
import '../widgets/nickname_dialog.dart';
import '../services/auth_service.dart';

class DialogUtils {
  static Future<void> showNicknameDialog(
    BuildContext context,
    AuthService authService, {
    Function()? onSuccess,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NicknameDialog(
        authService: authService,
        onSuccess: onSuccess,
      ),
    );

    if (result == true && onSuccess != null) {
      onSuccess();
    }
  }

  static void showErrorDialog(
    BuildContext context, {
    String title = '오류',
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
