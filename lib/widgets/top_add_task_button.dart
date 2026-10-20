import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../localization/app_locale.dart';

class TopAddTaskButton extends StatelessWidget {
  const TopAddTaskButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final color = provider.effectiveAddButtonColor;
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1F2937);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(
          context.tr('新增任務', 'Add task'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
