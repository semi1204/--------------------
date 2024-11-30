import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/auth_service.dart';

class NicknameDialog extends StatefulWidget {
  final AuthService authService;
  final Function()? onSuccess;

  const NicknameDialog({
    Key? key,
    required this.authService,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  final TextEditingController _nicknameController = TextEditingController();
  final Logger _logger = Logger();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _updateNickname() async {
    final nickname = _nicknameController.text.trim();

    if (!widget.authService.isValidDisplayName(nickname)) {
      setState(() {
        _errorText = '닉네임은 2-20자의 한글, 영문, 숫자만 가능합니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await widget.authService.updateUserDisplayName(nickname);
      _logger.i('Nickname updated successfully: $nickname');

      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onSuccess?.call();
      }
    } catch (e) {
      _logger.e('Error updating nickname: $e');
      setState(() {
        _errorText = '닉네임 업데이트 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('닉네임 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              labelText: '닉네임',
              hintText: '2-20자의 한글, 영문, 숫자',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            enabled: !_isLoading,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateNickname,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
