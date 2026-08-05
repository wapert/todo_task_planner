import 'package:flutter/material.dart';

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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF586174),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onReset != null && resetLabel != null)
          TextButton(onPressed: onReset, child: Text(resetLabel!)),
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
        // Clears the settings button floating in the top-right corner.
        const SizedBox(width: 40),
      ],
    );
  }
}
