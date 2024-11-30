import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class OXToggleButton extends StatelessWidget {
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  const OXToggleButton({
    super.key,
    required this.initialValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!initialValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 65,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color:
              initialValue ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          boxShadow: [
            BoxShadow(
              color: initialValue
                  ? const Color(0xFF6366F1).withOpacity(0.3)
                  : Colors.black12,
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: initialValue ? 33 : 0,
              top: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    initialValue
                        ? Ionicons.reader_outline
                        : Ionicons.calculator_outline,
                    size: 18,
                    color: initialValue
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
