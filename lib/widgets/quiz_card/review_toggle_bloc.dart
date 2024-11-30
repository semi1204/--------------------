import 'package:flutter/material.dart';
import 'package:any_animated_button/any_animated_button.dart';
import 'package:dartz/dartz.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';

class ReviewToggleBloc extends AnyAnimatedButtonBloc<bool, bool, String> {
  @override
  Future<Either<String, bool>> asyncAction(bool input) async {
    await Future.delayed(const Duration(milliseconds: 300));
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
        height: 32, // 높이를 36에서 32로 줄임
        decoration: BoxDecoration(
          color: Colors.transparent, // 배경색을 투명하게 변경
          border: Border.all(
            color: isInReviewList
                ? INCORRECT_OPTION_COLOR.withOpacity(0.5)
                : CORRECT_OPTION_COLOR.withOpacity(0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16), // 크기가 줄어든 만큼 radius도 조정
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12), // 패딩도 약간 줄임
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isInReviewList ? Icons.remove_circle : Icons.add_circle,
                    color: isInReviewList
                        ? INCORRECT_OPTION_COLOR
                        : CORRECT_OPTION_COLOR,
                    size: 18, // 아이콘 크기도 약간 줄임
                  ),
                  const SizedBox(width: 6), // 간격도 약간 줄임
                  Flexible(
                    child: Text(
                      isInReviewList ? '복습 제거' : '복습 추가',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13, // 폰트 크기도 약간 줄임
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
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
        size: 32, // 크기 조정
        backgroundColor: Colors.transparent, // 배경색 투명하게
      );

  @override
  AnyAnimatedButtonParams get successParams => defaultParams;

  @override
  AnyAnimatedButtonParams get errorParams => AnyAnimatedButtonParams.error(
        size: 32, // 크기 조정
        backgroundColor: Colors.transparent, // 배경색 투명하게
      );
}
