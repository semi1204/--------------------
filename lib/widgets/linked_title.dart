import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LinkedTitle extends StatelessWidget {
  final List<String> titles;
  final Function(int) onTap;
  final TextStyle? textStyle;

  const LinkedTitle({
    super.key,
    required this.titles,
    required this.onTap,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: titles.asMap().entries.map((entry) {
              int idx = entry.key;
              String title = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (idx > 0)
                    Text(' > ',
                        style: textStyle ??
                            getAppTextStyle(context, fontSize: 18)),
                  GestureDetector(
                    onTap: () => onTap(idx),
                    child: Text(
                      title,
                      style:
                          (textStyle ?? getAppTextStyle(context, fontSize: 18))
                              .copyWith(
                        fontWeight: idx == titles.length - 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                        decoration: idx < titles.length - 1
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    });
  }
}
