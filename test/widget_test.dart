import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_task_planner/main.dart';

void main() {
  testWidgets('planner hides integrations inside settings', (tester) async {
    await tester.pumpWidget(const TodoPlannerApp());

    expect(find.text('Todo Task Planner'), findsOneWidget);
    expect(find.text('Daily list'), findsOneWidget);
    expect(find.text('Calendar Accounts'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Calendar Accounts'), findsOneWidget);
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Yahoo Mail'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Set up').last);
    await tester.pumpAndSettle();

    expect(find.text('Yahoo Mail setup'), findsOneWidget);
    expect(find.textContaining('Yahoo OAuth credentials'), findsOneWidget);
  });

  testWidgets('user can add a task for multiple days', (tester) async {
    await tester.pumpWidget(const TodoPlannerApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(7));

    await tester.enterText(find.byType(TextField).first, 'Book dentist');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Tomorrow'));
    await tester.pumpAndSettle();

    final addTaskButton = find.widgetWithText(FilledButton, 'Add task').last;
    await tester.ensureVisible(addTaskButton);
    await tester.pumpAndSettle();
    await tester.tap(addTaskButton);
    await tester.pumpAndSettle();

    expect(find.text('Book dentist'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('weekday-1')));
    await tester.pumpAndSettle();

    expect(find.text('Book dentist'), findsOneWidget);
  });
}
