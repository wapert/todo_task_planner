import 'package:flutter/material.dart';

const pageHeaderTitleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w800,
  height: 1.15,
);

const pageHeaderSubtitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  height: 1.2,
);

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final foreground =
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: pageHeaderTitleStyle.copyWith(color: foreground)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: pageHeaderSubtitleStyle.copyWith(
              color: foreground.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }
}

/// Page heading with previous/next stepping, shared by the day view (Today)
/// and the week view (Plan). [onReset] is shown only when the user has
/// navigated away from the current day/week.
class PeriodHeader extends StatelessWidget {
  const PeriodHeader({
    super.key,
    required this.title,
    required this.onPrevious,
    required this.onNext,
    this.subtitle,
    this.onReset,
    this.resetLabel,
    this.previousTooltip,
    this.nextTooltip,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onReset;
  final String? resetLabel;
  final String? previousTooltip;
  final String? nextTooltip;

  @override
  Widget build(BuildContext context) {
    final foreground =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          child: PageHeaderText(title: title, subtitle: subtitle),
        ),
        if (onReset != null && resetLabel != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: foreground),
            onPressed: onReset,
            child: Text(resetLabel!),
          ),
        IconButton(
          tooltip: previousTooltip,
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        IconButton(
          tooltip: nextTooltip,
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}
