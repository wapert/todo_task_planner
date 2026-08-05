import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

import 'auth_service.dart';
import 'google_auth_config.dart';
import 'task_event.dart';

class GoogleCalendarService {
  GoogleCalendarService();

  static const List<String> scopes = googleCalendarScopes;

  Future<void> initialize() => AuthService.ensureGoogleInitialized();

  Future<String> createEvents(List<TaskCalendarEvent> events) async {
    if (events.isEmpty) {
      return '沒有選擇任何任務日期可同步。';
    }

    await initialize();

    // The account already consented to the Calendar scope during Google
    // sign-in, so this normally resolves silently from cache. Only fall back
    // to an interactive prompt if that has lapsed.
    final account =
        await GoogleSignIn.instance.attemptLightweightAuthentication() ??
        await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);

    final client = authorization.authClient(scopes: scopes);
    try {
      final api = calendar.CalendarApi(client);
      for (final taskEvent in events) {
        await api.events.insert(_toGoogleEvent(taskEvent), 'primary');
      }
      return '已建立 ${events.length} 個 Google 日曆事件。';
    } finally {
      client.close();
    }
  }

  calendar.Event _toGoogleEvent(TaskCalendarEvent taskEvent) {
    final event = calendar.Event(
      summary: taskEvent.title,
      description: taskEvent.notes.isEmpty ? null : taskEvent.notes,
    );

    final time = taskEvent.time;
    if (time == null) {
      event.start = calendar.EventDateTime(
        date: _dateOnly(taskEvent.day),
        timeZone: DateTime.now().timeZoneName,
      );
      event.end = calendar.EventDateTime(
        date: _dateOnly(taskEvent.day.add(const Duration(days: 1))),
        timeZone: DateTime.now().timeZoneName,
      );
    } else {
      final start = DateTime(
        taskEvent.day.year,
        taskEvent.day.month,
        taskEvent.day.day,
        time.hour,
        time.minute,
      );
      event.start = calendar.EventDateTime(
        dateTime: start,
        timeZone: DateTime.now().timeZoneName,
      );
      event.end = calendar.EventDateTime(
        dateTime: start.add(const Duration(hours: 1)),
        timeZone: DateTime.now().timeZoneName,
      );
    }

    return event;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class GoogleCalendarConfigurationException implements Exception {
  const GoogleCalendarConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
