import 'package:googleapis/calendar/v3.dart' as calendar;

/// Web OAuth client from the Firebase project, auto-created when the Google
/// sign-in provider was enabled. Android needs this as the `serverClientId` to
/// get an ID token for Firebase — the Android plugin does not fall back to the
/// `default_web_client_id` resource, so it has to be passed explicitly.
///
/// Client IDs are public; the matching client *secret* stays server-side and
/// must never be shipped in the app.
const String googleServerClientId =
    '599965724510-6vtqo0vfi924b6c8j7g5b4g8g659m56f.apps.googleusercontent.com';

/// Requested up front at sign-in so Calendar sync needs no second consent.
const List<String> googleCalendarScopes = <String>[
  calendar.CalendarApi.calendarScope,
];
