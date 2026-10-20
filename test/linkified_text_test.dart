import 'package:flutter_test/flutter_test.dart';
import 'package:todo_task_planner/widgets/linkified_text.dart';

void main() {
  test('finds multiple HTTP links and preserves surrounding text', () {
    final segments = linkifyWebText(
      '地圖：https://maps.google.com/?q=Taipei，網站 http://example.com.',
    );

    expect(
      segments
          .where((segment) => segment.uri != null)
          .map((segment) => segment.text),
      ['https://maps.google.com/?q=Taipei', 'http://example.com'],
    );
    expect(
      segments.map((segment) => segment.text).join(),
      '地圖：https://maps.google.com/?q=Taipei，網站 http://example.com.',
    );
  });

  test('ordinary comments remain a single text segment', () {
    final segments = linkifyWebText('記得帶雨傘');

    expect(segments, hasLength(1));
    expect(segments.single.text, '記得帶雨傘');
    expect(segments.single.uri, isNull);
  });

  test('recognizes map, music, document, and image links', () {
    expect(
      recognizeLink(Uri.parse('https://maps.google.com/?q=Taipei')).kind,
      RecognizedLinkKind.map,
    );
    expect(
      recognizeLink(Uri.parse('https://open.spotify.com/track/123')).kind,
      RecognizedLinkKind.spotify,
    );
    expect(
      recognizeLink(Uri.parse('https://docs.google.com/document/d/123')).kind,
      RecognizedLinkKind.googleDocs,
    );
    expect(
      recognizeLink(Uri.parse('https://example.com/photo.JPG?size=large')).kind,
      RecognizedLinkKind.image,
    );
  });

  test('extracts useful destination names from link URLs', () {
    expect(
      titleFromUrl(Uri.parse('https://maps.google.com/?q=Taipei%20101')),
      'Taipei 101',
    );
    expect(
      titleFromUrl(
        Uri.parse('https://music.apple.com/us/album/kind-of-blue/12345'),
      ),
      'kind of blue',
    );
    expect(
      titleFromUrl(
        Uri.parse('https://example.com/files/Quarterly_Report.xlsx'),
      ),
      'Quarterly Report.xlsx',
    );
    expect(
      titleFromUrl(
        Uri.parse(
          'https://www.google.com/maps/place/Taipei+Main+Station/@25,121',
        ),
      ),
      'Taipei Main Station',
    );
    final castle = Uri.parse(
      'https://www.google.com/maps/place/'
      'Saint+Catherine%E2%80%99s+Castle/@37.927149,12.3094551,17z/data=!4m6',
    );
    expect(titleFromUrl(castle), 'Saint Catherine’s Castle');
    expect(linkDisplayLabel(castle), '🗺️ 地圖：Saint Catherine’s Castle');
  });

  test('short Google Maps links use the redirect-resolution endpoint', () {
    final short = Uri.parse('https://maps.app.goo.gl/17x6FmvvmZ7Sz1G39');
    final lookup = metadataLookupUri(short);

    expect(lookup.host, 'maps.app.goo.gl');
    expect(lookup.queryParameters['_imcp'], '1');
  });

}
