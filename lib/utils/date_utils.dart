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

String dayLabel(DateTime date) {
  final today = dateOnly(DateTime.now());
  if (isSameDay(date, today)) {
    return '今天';
  }
  if (isSameDay(date, today.add(const Duration(days: 1)))) {
    return '明天';
  }
  return '${date.month}/${date.day} ${weekdayShort(date)}';
}

String assignedDaysLabel(List<DateTime> days) {
  final sortedDays = days.map(dateOnly).toList()..sort(compareDates);
  if (sortedDays.length == 1) {
    return dayLabel(sortedDays.first);
  }
  if (sortedDays.length == 7) {
    return '每天';
  }
  return '${sortedDays.length} 天';
}

String weekdayShort(DateTime date) {
  const names = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  return names[date.weekday - 1];
}

/// The Monday-to-Sunday week that [date] falls in.
List<DateTime> weekContaining(DateTime date) {
  final day = dateOnly(date);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return List.generate(7, (index) => monday.add(Duration(days: index)));
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
String fullDateLabel(DateTime date) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日 星期${weekdays[date.weekday - 1]}';
}
