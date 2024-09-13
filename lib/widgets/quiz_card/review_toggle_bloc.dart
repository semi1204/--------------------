import 'package:flutter/material.dart';
import 'package:any_animated_button/any_animated_button.dart';
import 'package:dartz/dartz.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';

class ReviewToggleBloc extends AnyAnimatedButtonBloc<bool, bool, String> {
  @override
  Future<Either<String, bool>> asyncAction(bool input) async {
    // Simulate an API call
    await Future.delayed(const Duration(milliseconds: 500));
    return Right(!input);
  }
}

class ReviewToggleButton extends CustomAnyAnimatedButton {
  const ReviewToggleButton({
    Key? key,
    required this.onTap,
    required this.isInReviewList,
    required this.bloc,
    required this.textColor,
  }) : super(key: key);

  @override
  final AnyAnimatedButtonBloc bloc;
  final VoidCallback onTap;
  final bool isInReviewList;
  final Color textColor;

  @override
  AnyAnimatedButtonParams get defaultParams => AnyAnimatedButtonParams(
        height: 32,
        decoration: BoxDecoration(
          color: isInReviewList ? INCORRECT_OPTION_COLOR : CORRECT_OPTION_COLOR,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isInReviewList ? Icons.remove_circle : Icons.add_circle,
                    color: isInReviewList ? Colors.red : Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isInReviewList ? '복습 제거' : '복습 추가',
                      style: TextStyle(color: textColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  AnyAnimatedButtonParams get progressParams =>
      AnyAnimatedButtonParams.progress(
        size: 40,
        backgroundColor:
            isInReviewList ? INCORRECT_OPTION_COLOR : CORRECT_OPTION_COLOR,
      );

  @override
  AnyAnimatedButtonParams get successParams => defaultParams;

  @override
  AnyAnimatedButtonParams get errorParams => AnyAnimatedButtonParams.error(
        size: 40,
        backgroundColor: Colors.red,
      );
}
