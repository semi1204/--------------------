import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Provider 패키지 추가
import 'package:nursing_quiz_app_6/providers/theme_provider.dart'; // ThemeProvider 임포트

class CustomLoginButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  final IconData icon;
  final String label;

  const CustomLoginButton({
    Key? key,
    required this.onTap,
    required this.isLoading,
    required this.icon,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        // primaryColor 대신 themeProvider의 buttonColor 사용
        color: themeProvider.buttonColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      // 로딩 인디케이터 색상을 themeProvider의 textColor로 변경
                      color: themeProvider.textColor,
                    ),
                  )
                else ...[
                  Icon(icon, color: themeProvider.iconColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(color: themeProvider.textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
