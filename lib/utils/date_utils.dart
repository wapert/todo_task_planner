import 'package:flutter/material.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

Map<DateTime, TimeOfDay> normalizeTimes(Map<DateTime, TimeOfDay> timesByDay) {
  return timesByDay.map((day, time) => MapEntry(dateOnly(day), time));
}

int compareDates(DateTime a, DateTime b) => dateOnly(a).compareTo(dateOnly(b));

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int minutesOfTime(TimeOfDay? time) {
  if (time == null) {
    return 24 * 60;
  }
  return time.hour * 60 + time.minute;
}

String dayLabel(DateTime date, {bool english = false}) {
  final today = dateOnly(DateTime.now());
  if (isSameDay(date, today)) {
    return english ? 'Today' : '今天';
  }
  if (isSameDay(date, today.add(const Duration(days: 1)))) {
    return english ? 'Tomorrow' : '明天';
  }
  return '${date.month}/${date.day} ${weekdayShort(date, english: english)}';
}

String assignedDaysLabel(List<DateTime> days, {bool english = false}) {
  final sortedDays = days.map(dateOnly).toList()..sort(compareDates);
  if (sortedDays.length == 1) {
    return dayLabel(sortedDays.first, english: english);
  }
  if (sortedDays.length == 7) {
    return english ? 'Every day' : '每天';
  }
  return english ? '${sortedDays.length} days' : '${sortedDays.length} 天';
}

/// '10/10 – 10/15' for a task that runs across a continuous stretch.
String spanLabel(List<DateTime> days) {
  final sorted = days.map(dateOnly).toList()..sort(compareDates);
  if (sorted.isEmpty) return '';
  if (sorted.length == 1) return '${sorted.first.month}/${sorted.first.day}';
  return dateRangeLabel(sorted.first, sorted.last);
}

/// 'Day 2 of 6' — where [day] falls within a span.
String spanProgressLabel(
  List<DateTime> days,
  DateTime day, {
  bool english = false,
}) {
  final sorted = days.map(dateOnly).toList()..sort(compareDates);
  final index = sorted.indexWhere((item) => isSameDay(item, day));
  if (index < 0) return '';
  return english
      ? 'Day ${index + 1} of ${sorted.length}'
      : '第 ${index + 1} 天／共 ${sorted.length} 天';
}

String weekdayShort(DateTime date, {bool english = false}) {
  const zhNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  const enNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final names = english ? enNames : zhNames;
  return names[date.weekday - 1];
}

/// The Sunday-to-Saturday week that [date] falls in.
List<DateTime> weekContaining(DateTime date) {
  final day = dateOnly(date);
  // DateTime.weekday is Mon=1 … Sun=7, so `% 7` maps Sunday to 0 and gives
  // the number of days back to the start of a Sunday-first week.
  final sunday = day.subtract(Duration(days: day.weekday % 7));
  return List.generate(7, (index) => sunday.add(Duration(days: index)));
}

/// Every day from [start] to [end] inclusive.
List<DateTime> daysInRange(DateTime start, DateTime end) {
  final first = dateOnly(start);
  final last = dateOnly(end);
  final span = last.difference(first).inDays;
  if (span < 0) return [first];
  return List.generate(span + 1, (index) => first.add(Duration(days: index)));
}

/// The calendar month that [date] falls in, as (first day, last day).
(DateTime, DateTime) monthBounds(DateTime date) {
  final first = DateTime(date.year, date.month, 1);
  final last = DateTime(date.year, date.month + 1, 0);
  return (first, last);
}

/// '8/4 - 8/10'.
String dateRangeLabel(DateTime start, DateTime end) {
  return '${start.month}/${start.day} - ${end.month}/${end.day}';
}

/// '8/4 - 8/10' for the given week.
String weekRangeLabel(List<DateTime> week) {
  return dateRangeLabel(week.first, week.last);
}

/// Full date, e.g. '8月4日 星期二'.
String fullDateLabel(DateTime date, {bool english = false}) {
  if (english) {
    return '${weekdayShort(date, english: true)}, ${date.month}/${date.day}';
  }
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日 星期${weekdays[date.weekday - 1]}';
}

/// Compact phone-friendly date, e.g. '8月12日（二）'.
String compactDateLabel(DateTime date, {bool english = false}) {
  if (english) {
    return '${date.month}/${date.day} (${weekdayShort(date, english: true)})';
  }
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日（${weekdays[date.weekday - 1]}）';
}
