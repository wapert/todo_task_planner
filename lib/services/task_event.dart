import 'package:flutter/material.dart';

class TaskCalendarEvent {
  const TaskCalendarEvent({
    required this.title,
    required this.day,
    required this.taskId,
    this.notes = '',
    this.time,
    this.externalEventId,
  });

  final String title;
  final DateTime day;
  final String taskId;
  final String notes;
  final TimeOfDay? time;
  final String? externalEventId;
}

typedef CalendarEventSynced =
    Future<void> Function(TaskCalendarEvent event, String externalEventId);
