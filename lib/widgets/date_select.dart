import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.onSelectedDateChanged,
  });

  final DateTime selectedDate;
  // void는 이 함수가 값을 반환하지 않음을 나타냅니다.
  // Function(DateTime)은 DateTime 타입의 매개변수를 받는 함수 타입을 의미합니다.
  // 즉, 이 변수는 날짜가 선택될 때 호출되는 콜백 함수를 저장합니다.
  final void Function(DateTime) onSelectedDateChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: EasyDateTimeLine(
        initialDate: selectedDate,
        onDateChange: onSelectedDateChanged,
        disabledDates: [
          for (DateTime date = DateTime.now().add(const Duration(days: 1));
              date.isBefore(DateTime.now().add(const Duration(days: 365)));
              date = date.add(const Duration(days: 1)))
            date,
        ],
        headerProps: const EasyHeaderProps(
          monthPickerType: MonthPickerType.dropDown,
          showHeader: false,
          showSelectedDate: true,
        ),
        dayProps: EasyDayProps(
          dayStructure: DayStructure.dayNumDayStr,
          activeDayStyle: DayStyle(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dayStrStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            dayNumStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          inactiveDayStyle: DayStyle(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // surface는 Material Design의 기본 표면 색상입니다.
              // 앱의 카드, 시트, 메뉴 등 UI 요소들의 배경색으로 사용됩니다.
              color: colorScheme.surface,
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            dayStrStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
            ),
            dayNumStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          todayHighlightStyle: TodayHighlightStyle.withBackground,
          todayHighlightColor: colorScheme.primaryContainer.withAlpha(90),
        ),
        timeLineProps: const EasyTimeLineProps(
          separatorPadding: 16,
        ),
      ),
    );
  }
}
