import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class DateRangeBottomSheet extends StatefulWidget {
  const DateRangeBottomSheet({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.initialDateRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;

  @override
  State<DateRangeBottomSheet> createState() => _DateRangeBottomSheetState();
}

class _DateRangeBottomSheetState extends State<DateRangeBottomSheet> {
  late DateTime focusedDay;
  DateTime? rangeStart;
  DateTime? rangeEnd;

  @override
  void initState() {
    super.initState();
    rangeStart = widget.initialDateRange?.start;
    rangeEnd = widget.initialDateRange?.end;
    focusedDay = rangeStart ?? widget.lastDate;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 14),
            _header(context),
            _selectedRangeBanner(),
            const SizedBox(height: 12),
            _monthControls(),
            _calendar(),
            const SizedBox(height: 12),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '분실 일자 선택',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _selectedRangeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _selectedRangeText,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _monthControls() {
    return Row(
      children: [
        IconButton(
          onPressed: _canMoveToPreviousMonth ? () => _moveMonth(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _yearDropdown(),
              const SizedBox(width: 8),
              _monthDropdown(),
            ],
          ),
        ),
        IconButton(
          onPressed: _canMoveToNextMonth ? () => _moveMonth(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _calendar() {
    return TableCalendar<void>(
      firstDay: widget.firstDate,
      lastDay: widget.lastDate,
      focusedDay: focusedDay,
      rangeStartDay: rangeStart,
      rangeEndDay: rangeEnd,
      rangeSelectionMode: RangeSelectionMode.disabled,
      calendarFormat: CalendarFormat.month,
      headerVisible: false,
      calendarBuilders: CalendarBuilders(dowBuilder: _dayOfWeekBuilder),
      calendarStyle: const CalendarStyle(
        rangeHighlightColor: Color(0xFFEAF2FF),
        rangeStartDecoration: BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        rangeEndDecoration: BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Color(0xFF93C5FD),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        outsideDaysVisible: false,
      ),
      onDaySelected: (selectedDay, focused) {
        _selectDay(selectedDay, focused);
      },
      onPageChanged: (focused) {
        setState(() {
          focusedDay = focused;
        });
      },
    );
  }

  void _selectDay(DateTime selectedDay, DateTime focused) {
    setState(() {
      focusedDay = focused;

      if (rangeStart == null || rangeEnd != null) {
        rangeStart = selectedDay;
        rangeEnd = null;
        return;
      }

      if (selectedDay.isBefore(rangeStart!)) {
        rangeEnd = rangeStart;
        rangeStart = selectedDay;
        return;
      }

      rangeEnd = selectedDay;
    });
  }

  Widget _actionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                rangeStart = null;
                rangeEnd = null;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('초기화'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: rangeStart == null
                ? null
                : () {
                    Navigator.of(context).pop(
                      DateTimeRange(
                        start: rangeStart!,
                        end: rangeEnd ?? rangeStart!,
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('적용'),
          ),
        ),
      ],
    );
  }

  Widget _dayOfWeekBuilder(BuildContext context, DateTime day) {
    const List<String> weekDays = ['월', '화', '수', '목', '금', '토', '일'];
    final bool isSunday = day.weekday == DateTime.sunday;
    final bool isSaturday = day.weekday == DateTime.saturday;

    return Center(
      child: Text(
        weekDays[day.weekday - 1],
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isSunday
              ? const Color(0xFFDC2626)
              : isSaturday
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _yearDropdown() {
    final List<int> years = [
      for (int year = widget.firstDate.year; year <= widget.lastDate.year; year++)
        year,
    ];

    return DropdownButton<int>(
      value: focusedDay.year,
      underline: const SizedBox.shrink(),
      items: years.map((year) {
        return DropdownMenuItem<int>(
          value: year,
          child: Text(
            '$year년',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
      onChanged: (year) {
        if (year == null) {
          return;
        }

        setState(() {
          focusedDay = _clampFocusedDay(DateTime(year, focusedDay.month));
        });
      },
    );
  }

  Widget _monthDropdown() {
    return DropdownButton<int>(
      value: focusedDay.month,
      underline: const SizedBox.shrink(),
      items: List.generate(12, (index) {
        final int month = index + 1;

        return DropdownMenuItem<int>(
          value: month,
          child: Text(
            '$month월',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }),
      onChanged: (month) {
        if (month == null) {
          return;
        }

        setState(() {
          focusedDay = _clampFocusedDay(DateTime(focusedDay.year, month));
        });
      },
    );
  }

  String get _selectedRangeText {
    if (rangeStart == null) {
      return '시작일을 선택하세요';
    }

    if (rangeEnd == null) {
      return '${_formatDate(rangeStart!)}  ~  종료일 선택';
    }

    return '${_formatDate(rangeStart!)}  ~  ${_formatDate(rangeEnd!)}';
  }

  bool get _canMoveToPreviousMonth {
    final DateTime previousMonth = DateTime(
      focusedDay.year,
      focusedDay.month - 1,
    );

    return !previousMonth.isBefore(_monthOnly(widget.firstDate));
  }

  bool get _canMoveToNextMonth {
    final DateTime nextMonth = DateTime(
      focusedDay.year,
      focusedDay.month + 1,
    );

    return !nextMonth.isAfter(_monthOnly(widget.lastDate));
  }

  void _moveMonth(int offset) {
    setState(() {
      focusedDay = DateTime(focusedDay.year, focusedDay.month + offset);
    });
  }

  DateTime _clampFocusedDay(DateTime day) {
    final DateTime month = _monthOnly(day);
    final DateTime firstMonth = _monthOnly(widget.firstDate);
    final DateTime lastMonth = _monthOnly(widget.lastDate);

    if (month.isBefore(firstMonth)) {
      return widget.firstDate;
    }

    if (month.isAfter(lastMonth)) {
      return widget.lastDate;
    }

    return day;
  }

  DateTime _monthOnly(DateTime date) {
    return DateTime(date.year, date.month);
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
