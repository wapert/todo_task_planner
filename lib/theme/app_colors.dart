import 'package:flutter/material.dart';

import '../models/planner_task.dart';

/// Traffic-light priority colours, shared by the task rows and the progress
/// charts so the two can't drift apart.
Color priorityColor(TaskPriority priority) => switch (priority) {
  TaskPriority.low => const Color(0xFF16A34A), // green
  TaskPriority.medium => const Color(0xFFE1A100), // yellow
  TaskPriority.high => const Color(0xFFE10600), // red
};

/// Matches the accent color of the "Flagged" smart list in Apple Reminders.
const Color flaggedColor = Color(0xFFFF9500);

/// Fill color for the weekday selector cards.
const Color weekdayCardColor = Color(0xFFFFFFF0);

/// Page background behind the white content panels.
const Color pageBackgroundColor = Color(0xFFF2F4F7);

/// Shared chrome color for the top app bar and bottom navigation bar.
const Color toolbarBackgroundColor = Color(0xFFE5E7EB);
