import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => '低',
    TaskPriority.medium => '中',
    TaskPriority.high => '高',
  };
}

class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required List<DateTime> days,
    required this.source,
    Map<DateTime, TimeOfDay>? timesByDay,
    this.notes = '',
    this.priority = TaskPriority.medium,
    this.isDone = false,
  }) : days = days.map(dateOnly).toList(),
       timesByDay = normalizeTimes(timesByDay ?? {});

  final String id;
  String title;
  List<DateTime> days;
  Map<DateTime, TimeOfDay> timesByDay;
  String source;
  String notes;
  TaskPriority priority;
  bool isDone;

  TimeOfDay? timeForDay(DateTime day) {
    final normalizedDay = dateOnly(day);
    for (final entry in timesByDay.entries) {
      if (isSameDay(entry.key, normalizedDay)) {
        return entry.value;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'notes': notes,
      'days': days.map((day) => day.toIso8601String()).toList(),
      'timesByDay': timesByDay.map(
        (day, time) => MapEntry(day.toIso8601String(), {
          'hour': time.hour,
          'minute': time.minute,
        }),
      ),
      'source': source,
      'priority': priority.name,
      'isDone': isDone,
    };
  }

  factory PlannerTask.fromMap(String id, Map<String, dynamic> data) {
    final rawDays = (data['days'] as List<dynamic>? ?? []);
    final rawTimes = (data['timesByDay'] as Map<String, dynamic>? ?? {});
    return PlannerTask(
      id: id,
      title: data['title'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      days: rawDays.map((day) => DateTime.parse(day as String)).toList(),
      timesByDay: rawTimes.map((key, value) {
        final entry = value as Map<String, dynamic>;
        return MapEntry(
          DateTime.parse(key),
          TimeOfDay(hour: entry['hour'] as int, minute: entry['minute'] as int),
        );
      }),
      source: data['source'] as String? ?? 'Manual',
      priority: TaskPriority.values.byName(
        data['priority'] as String? ?? 'medium',
      ),
      isDone: data['isDone'] as bool? ?? false,
    );
  }
}
