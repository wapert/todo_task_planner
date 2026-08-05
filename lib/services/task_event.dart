import 'package:flutter/material.dart';

class TaskCalendarEvent {
  const TaskCalendarEvent({
    required this.title,
    required this.day,
    this.notes = '',
    this.time,
  });

  final String title;
  final DateTime day;
  final String notes;
  final TimeOfDay? time;
}
