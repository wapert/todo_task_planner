import 'package:flutter_test/flutter_test.dart';
import 'package:todo_task_planner/models/planner_task.dart';

void main() {
  group('calendar sync identifiers', () {
    test('round-trip through task persistence', () {
      final task = PlannerTask(
        id: 'task-1',
        title: 'Meeting',
        days: [DateTime(2026, 8, 14)],
        source: 'Manual',
        googleCalendarEventIds: {'2026-08-14': 'google-event'},
        appleCalendarEventIds: {'2026-08-14': 'apple-event'},
      );

      final restored = PlannerTask.fromMap(task.id, task.toMap());

      expect(restored.googleCalendarEventIds['2026-08-14'], 'google-event');
      expect(restored.appleCalendarEventIds['2026-08-14'], 'apple-event');
    });

    test('old stored tasks default to empty identifier maps', () {
      final restored = PlannerTask.fromMap('legacy', {
        'title': 'Legacy task',
        'days': <String>[],
        'source': 'Manual',
      });

      expect(restored.googleCalendarEventIds, isEmpty);
      expect(restored.appleCalendarEventIds, isEmpty);
    });

    test('day key ignores time and uses stable zero-padded date', () {
      expect(
        PlannerTask.calendarDayKey(DateTime(2026, 3, 7, 23, 59)),
        '2026-03-07',
      );
    });
  });
}
