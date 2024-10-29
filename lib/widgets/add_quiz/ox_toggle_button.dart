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
    return Switch(
      value: initialValue,
      onChanged: onChanged,
      activeColor: Colors.orange[700],
      inactiveTrackColor: Colors.blue[700],
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          return Colors.white;
        },
      ),
      thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            // return const Icon(Icons.calculate_outlined, color: Colors.orange);
            // // TODO: Replace with Ionicons package icon when available
            return const Icon(Ionicons.reader_outline, color: Colors.orange);
          }
          return const Icon(Ionicons.calculator_outline, color: Colors.blue);
        },
      ),
    );
  }
}
