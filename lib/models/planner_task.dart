import 'package:flutter/material.dart';

import '../utils/date_utils.dart';

enum TaskPriority { low, medium, high }

/// Built-in categories offered in the task form. A task may also carry any
/// other string, entered via 自訂.
const List<String> presetTaskCategories = ['工作', '家庭', '運動', '休閒', '進修'];

String localizedTaskCategory(String category, {required bool english}) {
  if (!english) return category;
  return switch (category) {
    '工作' => 'Work',
    '家庭' => 'Family',
    '運動' => 'Exercise',
    '休閒' => 'Leisure',
    '進修' => 'Learning',
    _ => category,
  };
}

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => '低',
    TaskPriority.medium => '中',
    TaskPriority.high => '高',
  };

  String localizedLabel({required bool english}) => english
      ? switch (this) {
          TaskPriority.low => 'Low',
          TaskPriority.medium => 'Medium',
          TaskPriority.high => 'High',
        }
      : label;
}

class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required List<DateTime> days,
    required this.source,
    Map<DateTime, TimeOfDay>? timesByDay,
    this.notes = '',
    this.category = '',
    this.priority = TaskPriority.medium,
    bool isDone = false,
    Set<String>? completedDays,
    this.reminderMinutesBefore,
    Map<String, String>? googleCalendarEventIds,
    Map<String, String>? appleCalendarEventIds,
    Set<String>? acknowledgedReminderDays,
    this.isSpan = false,
  }) : days = days.map(dateOnly).toList(),
       timesByDay = normalizeTimes(timesByDay ?? {}),
       googleCalendarEventIds = Map.of(googleCalendarEventIds ?? {}),
       appleCalendarEventIds = Map.of(appleCalendarEventIds ?? {}),
       acknowledgedReminderDays = {...?acknowledgedReminderDays},
       completedDays = {...?completedDays} {
    // Legacy migration: a task saved before per-day completion carries a
    // single isDone flag and no completedDays set. Treat it as done on every
    // one of its days, so previously-finished tasks still read as done.
    if (completedDays == null && isDone) {
      this.completedDays.addAll(this.days.map(calendarDayKey));
    }
  }

  final String id;
  String title;
  List<DateTime> days;
  Map<DateTime, TimeOfDay> timesByDay;
  String source;
  String notes;

  /// Free-form; one of [presetTaskCategories] or a user-entered 自訂 value.
  /// Empty when the task has no category.
  String category;
  TaskPriority priority;

  /// Day keys (yyyy-MM-dd) the user has marked complete. Per-day, so a task
  /// that spans or repeats across several days can be done on some and still
  /// open on others, independently.
  Set<String> completedDays;

  /// Whether [day] specifically is marked complete.
  bool isDoneOn(DateTime day) =>
      completedDays.contains(calendarDayKey(dateOnly(day)));

  /// The whole task counts as done only when every one of its days is — used
  /// for list filters and progress totals, not for the per-day checkbox.
  bool get isDone =>
      days.isNotEmpty &&
      days.every((day) => completedDays.contains(calendarDayKey(day)));

  /// Minutes before the task's time that a reminder fires, or null for no
  /// reminder. 0 means "at the scheduled time".
  int? reminderMinutesBefore;

  /// True when [days] is one continuous stretch the task runs across — a
  /// trip, a course — rather than separate occasions that happen to share a
  /// title. Both store the same list of days; this is what says whether the
  /// task is *one thing lasting a while* or *a thing repeated*, which is the
  /// difference between "6 天" and "10/10 – 10/15".
  bool isSpan;

  /// Day keys (yyyy-MM-dd) whose fired reminder the user has dismissed.
  /// Stored per day rather than per task, because a repeating task's Monday
  /// occurrence being seen says nothing about its Tuesday one. Persisted so
  /// dismissing on one device does not leave the mark showing on another.
  Set<String> acknowledgedReminderDays;

  /// Calendar event identifiers, keyed by the task date (yyyy-MM-dd).
  /// Keeping the provider IDs lets repeated syncs update instead of insert.
  Map<String, String> googleCalendarEventIds;
  Map<String, String> appleCalendarEventIds;

  static String calendarDayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

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
      'category': category,
      'priority': priority.name,
      'isDone': isDone,
      'completedDays': completedDays.toList(),
      'reminderMinutesBefore': reminderMinutesBefore,
      'acknowledgedReminderDays': acknowledgedReminderDays.toList(),
      'isSpan': isSpan,
      'googleCalendarEventIds': googleCalendarEventIds,
      'appleCalendarEventIds': appleCalendarEventIds,
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
      category: data['category'] as String? ?? '',
      priority: TaskPriority.values.byName(
        data['priority'] as String? ?? 'medium',
      ),
      isDone: data['isDone'] as bool? ?? false,
      completedDays: (data['completedDays'] as List<dynamic>?)
          ?.map((value) => value.toString())
          .toSet(),
      reminderMinutesBefore: (data['reminderMinutesBefore'] as num?)?.toInt(),
      acknowledgedReminderDays:
          (data['acknowledgedReminderDays'] as List<dynamic>? ?? [])
              .map((value) => value.toString())
              .toSet(),
      isSpan: data['isSpan'] as bool? ?? false,
      googleCalendarEventIds: _stringMap(data['googleCalendarEventIds']),
      appleCalendarEventIds: _stringMap(data['appleCalendarEventIds']),
    );
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, item) => MapEntry(key.toString(), item.toString()));
  }
}
