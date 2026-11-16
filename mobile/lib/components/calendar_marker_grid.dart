import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../util.dart';

class CalendarMarkerGrid extends StatelessWidget {
  final DateTime selected;
  final bool monthView;
  final Set<String> bookedDates;
  final Set<String> openDates;
  final Set<String> activityDates;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const CalendarMarkerGrid({
    super.key,
    required this.selected,
    required this.monthView,
    required this.bookedDates,
    required this.openDates,
    required this.activityDates,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final days = monthView
        ? monthGrid(selected)
        : List.generate(7, (index) {
            final start = startOfWeek(selected);
            return DateTime(start.year, start.month, start.day + index);
          });
    final label = monthView
        ? '${monthNames[selected.month - 1]} ${selected.year}'
        : '${fmtDateLong(days.first)} – ${fmtDateLong(days.last)}';
    final today = ymd(DateTime.now());
    final selectedKey = ymd(selected);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onPrevious,
              tooltip: 'Previous ${monthView ? 'month' : 'week'}',
              icon: const Icon(Icons.chevron_left),
            ),
            Text(label,
                style: context.textLg.copyWith(
                    color: context.textColor, fontWeight: FontWeight.w800)),
            IconButton(
              onPressed: onNext,
              tooltip: 'Next ${monthView ? 'month' : 'week'}',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final weekday in weekdayNames)
              Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: context.textXs.copyWith(
                        color: context.textMuted, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 5.0;
            const cellHeight = 44.0;
            final cellWidth = (constraints.maxWidth - spacing * 6) / 7;
            return GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: cellWidth / cellHeight,
              children: [
                for (final date in days)
                  _CalendarDay(
                    date: date,
                    selectedKey: selectedKey,
                    todayKey: today,
                    showOutsideMonth: monthView && date.month != selected.month,
                    hasBooking: bookedDates.contains(ymd(date)),
                    hasOpenTime: openDates.contains(ymd(date)),
                    hasActivity: activityDates.contains(ymd(date)),
                    onTap: () => onSelect(date),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final String selectedKey;
  final String todayKey;
  final bool showOutsideMonth;
  final bool hasBooking;
  final bool hasOpenTime;
  final bool hasActivity;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.date,
    required this.selectedKey,
    required this.todayKey,
    required this.showOutsideMonth,
    required this.hasBooking,
    required this.hasOpenTime,
    required this.hasActivity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateKey = ymd(date);
    final isSelected = dateKey == selectedKey;
    final isToday = dateKey == todayKey;

    return Semantics(
      button: true,
      label: [
        fmtDateLong(date),
        if (hasBooking) 'consultation',
        if (hasOpenTime) 'open time',
        if (hasActivity) 'new activity',
      ].join(', '),
      child: GestureDetector(
        key: ValueKey('calendar-day-$dateKey'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: DesignTokens.transitionFast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? context.brandPrimary : context.surfaceHover,
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            border:
                isToday ? Border.all(color: context.textColor, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : showOutsideMonth
                          ? context.textMuted.withValues(alpha: 0.5)
                          : context.textColor,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasBooking)
                      _MarkerDot(
                        key: ValueKey('booked-marker-$dateKey'),
                        color: isSelected ? Colors.white : context.brandPrimary,
                        tooltip: 'Consultation',
                      ),
                    if (hasOpenTime)
                      const _MarkerDot(
                        key: Key('open-marker'),
                        color: Color(0xFF16A34A),
                        tooltip: 'Open time',
                      ),
                    if (hasActivity)
                      const _MarkerDot(
                        key: Key('activity-marker'),
                        color: Color(0xFFF59E0B),
                        tooltip: 'New activity',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerDot extends StatelessWidget {
  final Color color;
  final String tooltip;

  const _MarkerDot({super.key, required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Tooltip(
          message: tooltip,
          child: DecoratedBox(
            key: ValueKey(
                'marker-${tooltip.toLowerCase().replaceAll(' ', '-')}'),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 5, height: 5),
          ),
        ),
      );
}

class CalendarMarkerLegend extends StatelessWidget {
  const CalendarMarkerLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _CalendarLegendItem(
              color: context.brandPrimary, label: 'Consultation'),
          const _CalendarLegendItem(
              color: Color(0xFF16A34A), label: 'Open time'),
          const _CalendarLegendItem(
              color: Color(0xFFF59E0B), label: 'New activity'),
        ],
      );
}

class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: context.textXs.copyWith(color: context.textMuted)),
        ],
      );
}
