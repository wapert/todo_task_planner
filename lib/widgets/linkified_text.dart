import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LinkTextSegment {
  const LinkTextSegment(this.text, {this.uri});

  final String text;
  final Uri? uri;
}

enum RecognizedLinkKind {
  map,
  appleMusic,
  spotify,
  word,
  excel,
  powerpoint,
  googleDocs,
  googleSheets,
  googleSlides,
  image,
  web,
}

class RecognizedLink {
  const RecognizedLink(this.kind, this.label);

  final RecognizedLinkKind kind;
  final String label;
}

RecognizedLink recognizeLink(Uri uri) {
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  final extension = path.split('.').last;

  if (const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'}.contains(extension)) {
    return const RecognizedLink(RecognizedLinkKind.image, '🖼️ 圖片');
  }
  if (host == 'maps.apple.com' ||
      host == 'maps.app.goo.gl' ||
      host.startsWith('maps.google.') ||
      host == 'goo.gl' && path.startsWith('/maps') ||
      host.contains('google.') && path.startsWith('/maps') ||
      host == 'waze.com' ||
      host.endsWith('.waze.com')) {
    return const RecognizedLink(RecognizedLinkKind.map, '🗺️ 地圖');
  }
  if (host == 'music.apple.com') {
    return const RecognizedLink(
      RecognizedLinkKind.appleMusic,
      '🎵 Apple Music',
    );
  }
  if (host == 'open.spotify.com' || host.endsWith('.spotify.com')) {
    return const RecognizedLink(RecognizedLinkKind.spotify, '🎵 Spotify');
  }
  if (const {'doc', 'docx'}.contains(extension)) {
    return const RecognizedLink(RecognizedLinkKind.word, '📄 Word 文件');
  }
  if (const {'xls', 'xlsx', 'csv'}.contains(extension)) {
    return const RecognizedLink(RecognizedLinkKind.excel, '📊 Excel 試算表');
  }
  if (const {'ppt', 'pptx'}.contains(extension)) {
    return const RecognizedLink(
      RecognizedLinkKind.powerpoint,
      '📽️ PowerPoint',
    );
  }
  if (host == 'docs.google.com') {
    if (path.startsWith('/document')) {
      return const RecognizedLink(
        RecognizedLinkKind.googleDocs,
        '📄 Google Docs',
      );
    }
    if (path.startsWith('/spreadsheets')) {
      return const RecognizedLink(
        RecognizedLinkKind.googleSheets,
        '📊 Google Sheets',
      );
    }
    if (path.startsWith('/presentation')) {
      return const RecognizedLink(
        RecognizedLinkKind.googleSlides,
        '📽️ Google Slides',
      );
    }
  }
  if (host == '1drv.ms' ||
      host.endsWith('.sharepoint.com') ||
      host.endsWith('.office.com') ||
      host.endsWith('.microsoft365.com')) {
    return const RecognizedLink(RecognizedLinkKind.word, '📄 Microsoft 文件');
  }
  return const RecognizedLink(RecognizedLinkKind.web, '網頁連結');
}

final _webLinkPattern = RegExp(
  r'https?://[^\s<>\[\]{}"“”，。；：！？]+',
  caseSensitive: false,
);

final _trailingPunctuation = RegExp(r'[.,;:!?。，；：！？]+$');

final _linkTitleCache = <String, Future<String>>{};

Future<String> resolveLinkTitle(Uri uri) =>
    _linkTitleCache.putIfAbsent(uri.toString(), () => _resolveLinkTitle(uri));

Future<String> _resolveLinkTitle(Uri uri) async {
  final quickTitle = titleFromUrl(uri);
  try {
    if (uri.host.toLowerCase() == 'maps.app.goo.gl') {
      final redirectTitle = await _resolveShortGoogleMapTitle(uri);
      if (redirectTitle.isNotEmpty) return redirectTitle;
    }
    final lookupUri = metadataLookupUri(uri);
    final response = await http
        .get(
          lookupUri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode >= 200 && response.statusCode < 400) {
      final finalUri = response.request?.url ?? uri;
      final redirectedTitle = titleFromUrl(finalUri);
      if (recognizeLink(uri).kind == RecognizedLinkKind.map) {
        final mapTitle = _extractMapTitle(response.body, finalUri);
        if (mapTitle.isNotEmpty) return mapTitle;
      }
      final htmlTitle = _extractHtmlTitle(response.body);
      if (htmlTitle.isNotEmpty && !_isGenericServiceTitle(htmlTitle)) {
        return htmlTitle;
      }
      if (redirectedTitle != quickTitle) return redirectedTitle;
    }
  } catch (_) {
    // Keep the URL-derived fallback when offline or authorization is needed.
  }
  return quickTitle;
}

Future<String> _resolveShortGoogleMapTitle(Uri uri) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', metadataLookupUri(uri))
      ..followRedirects = false
      ..headers['User-Agent'] =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/537.36 Safari/537.36';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 5));
    await response.stream.drain<void>();
    final location = response.headers['location'];
    if (location == null || location.isEmpty) return '';
    final destination = uri.resolve(location);
    final title = titleFromUrl(destination);
    return _isGenericServiceTitle(title) ? '' : title;
  } finally {
    client.close();
  }
}

Uri metadataLookupUri(Uri uri) {
  if (uri.host.toLowerCase() != 'maps.app.goo.gl') return uri;
  return uri.replace(queryParameters: {...uri.queryParameters, '_imcp': '1'});
}

String titleFromUrl(Uri uri) {
  final recognized = recognizeLink(uri);
  if (recognized.kind == RecognizedLinkKind.map) {
    for (final key in const ['q', 'query', 'destination', 'daddr', 'address']) {
      final value = uri.queryParameters[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final mapSegments = uri.pathSegments;
    for (final marker in const ['place', 'search']) {
      final index = mapSegments.indexOf(marker);
      if (index >= 0 && index + 1 < mapSegments.length) {
        final name = mapSegments[index + 1].replaceAll('+', ' ').trim();
        if (name.isNotEmpty && !name.startsWith('@')) return name;
      }
    }
  }
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.isNotEmpty) {
    var candidate = segments.last;
    if (RegExp(r'^(id)?\d+$', caseSensitive: false).hasMatch(candidate) &&
        segments.length > 1) {
      candidate = segments[segments.length - 2];
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{16,}$').hasMatch(candidate)) {
      candidate = candidate.replaceAll(RegExp(r'[-_]+'), ' ').trim();
      if (candidate.isNotEmpty &&
          !const {
            'document',
            'spreadsheets',
            'presentation',
            'track',
            'album',
            'playlist',
          }.contains(candidate.toLowerCase())) {
        return candidate;
      }
    }
  }
  return recognized.label.replaceFirst(RegExp(r'^\S+\s'), '');
}

String linkDisplayLabel(Uri uri) {
  final recognized = recognizeLink(uri);
  final title = titleFromUrl(uri);
  final genericLabel = recognized.label.replaceFirst(RegExp(r'^\S+\s'), '');
  if (recognized.kind == RecognizedLinkKind.map &&
      title.isNotEmpty &&
      title != genericLabel) {
    return '${recognized.label}：$title';
  }
  return recognized.label;
}

bool _isGenericServiceTitle(String title) {
  final normalized = title.toLowerCase().trim();
  return const {
    'google maps',
    'apple maps',
    'spotify',
    'apple music',
    'google docs',
    'google sheets',
    'google slides',
  }.contains(normalized);
}

String _extractHtmlTitle(String html) {
  final patterns = [
    RegExp(
      r'''<meta[^>]+(?:property|name)=["'](?:og:title|twitter:title)["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["'](?:og:title|twitter:title)["']''',
      caseSensitive: false,
    ),
    RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(html);
    if (match == null) continue;
    final title = _decodeHtml(
      match.group(1)!,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isNotEmpty) return title;
  }
  return '';
}

String _extractMapTitle(String html, Uri finalUri) {
  final redirected = titleFromUrl(finalUri);
  if (!_isGenericServiceTitle(redirected)) return redirected;

  final normalizedHtml = _decodeHtml(
    html,
  ).replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');
  final urlMatch = RegExp(
    r'''https?://(?:www\.)?google\.[^/"']+/maps/(?:place|search)/([^/"'?<]+)''',
    caseSensitive: false,
  ).firstMatch(normalizedHtml);
  if (urlMatch != null) {
    final encodedName = urlMatch.group(1)!.replaceAll('+', ' ');
    final name = Uri.decodeComponent(encodedName).trim();
    if (name.isNotEmpty) return name;
  }

  for (final pattern in [
    RegExp(
      r'''<meta[^>]+(?:itemprop|property)=["'](?:name|og:title)["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ),
    RegExp(
      r'''<meta[^>]+content=["']([^"']+)["'][^>]+(?:itemprop|property)=["'](?:name|og:title)["']''',
      caseSensitive: false,
    ),
  ]) {
    final match = pattern.firstMatch(normalizedHtml);
    if (match == null) continue;
    final name = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isNotEmpty && !_isGenericServiceTitle(name)) return name;
  }
  return '';
}

String _decodeHtml(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

List<LinkTextSegment> linkifyWebText(String text) {
  final segments = <LinkTextSegment>[];
  var cursor = 0;
  for (final match in _webLinkPattern.allMatches(text)) {
    if (match.start > cursor) {
      segments.add(LinkTextSegment(text.substring(cursor, match.start)));
    }
    final raw = match.group(0)!;
    final link = raw.replaceFirst(_trailingPunctuation, '');
    final punctuation = raw.substring(link.length);
    final uri = Uri.tryParse(link);
    segments.add(LinkTextSegment(link, uri: uri));
    if (punctuation.isNotEmpty) segments.add(LinkTextSegment(punctuation));
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(LinkTextSegment(text.substring(cursor)));
  }
  return segments;
}

/// Selectable task-comment text whose HTTP(S) URLs open through the OS.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟此連結。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final segments = linkifyWebText(widget.text);
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    final span = TextSpan(
      style: baseStyle,
      children: segments.map((segment) {
        final uri = segment.uri;
        if (uri == null) return TextSpan(text: segment.text);
        final recognizer = TapGestureRecognizer()..onTap = () => _open(uri);
        _recognizers.add(recognizer);
        return TextSpan(
          text: '【${linkDisplayLabel(uri)}】',
          style: linkStyle,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        );
      }).toList(),
    );
    final text = widget.maxLines != null
        ? Text.rich(span, maxLines: widget.maxLines, overflow: widget.overflow)
        : SelectableText.rich(span);
    final imageUris = widget.maxLines == null
        ? segments
              .where((segment) => segment.uri != null)
              .map((segment) => segment.uri!)
              .where(
                (uri) => recognizeLink(uri).kind == RecognizedLinkKind.image,
              )
              .toSet()
              .toList()
        : const <Uri>[];
    final previewUris = widget.maxLines == null
        ? segments
              .where((segment) => segment.uri != null)
              .map((segment) => segment.uri!)
              .where((uri) {
                final kind = recognizeLink(uri).kind;
                return kind != RecognizedLinkKind.web &&
                    kind != RecognizedLinkKind.image;
              })
              .toSet()
              .toList()
        : const <Uri>[];
    if (imageUris.isEmpty && previewUris.isEmpty) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        const SizedBox(height: 8),
        for (final uri in previewUris) ...[
          _RecognizedLinkCard(uri: uri, onOpen: () => _open(uri)),
          const SizedBox(height: 8),
        ],
        for (final uri in imageUris) ...[
          _LinkedImage(uri: uri, onOpen: () => _open(uri)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RecognizedLinkCard extends StatelessWidget {
  const _RecognizedLinkCard({required this.uri, required this.onOpen});

  final Uri uri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final recognized = recognizeLink(uri);
    final fallbackTitle = titleFromUrl(uri);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.open_in_new, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: resolveLinkTitle(uri),
                      initialData: fallbackTitle,
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? fallbackTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      recognized.label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedImage extends StatelessWidget {
  const _LinkedImage({required this.uri, required this.onOpen});

  final Uri uri;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '開啟圖片',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Image.network(
              uri.toString(),
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) => Container(
                height: 80,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined),
                    SizedBox(width: 8),
                    Text('無法載入圖片'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
