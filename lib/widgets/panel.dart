import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';

/// A rounded card using the account's selected page background.
/// The shared building block behind most content sections in the app.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final IconData? icon;
  final Widget child;

  /// Trimmed for lists of task rows, where the panel's inset sits inside the
  /// page's own and the two together cost more width than the rows can spare.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final background = context.watch<TaskProvider>().backgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E7EE)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
