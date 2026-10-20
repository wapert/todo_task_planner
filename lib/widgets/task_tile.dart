import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/planner_task.dart';
import '../localization/app_locale.dart';
import '../providers/task_provider.dart';
import '../utils/date_utils.dart';
import 'linkified_text.dart';
import 'task_reminder_field.dart';

class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.selectedDay,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTask task;
  final DateTime selectedDay;
  final VoidCallback onToggle;

  /// Opens the edit sheet.
  final VoidCallback onEdit;

  /// Confirms and deletes — reached by swiping the row left.
  final VoidCallback onDelete;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  /// Long notes are clipped so one task cannot push the rest off screen.
  /// Expanding happens in place, which is what the enlarge button was for.
  bool _notesExpanded = false;

  /// Lines shown before the notes are clipped.
  static const _notesCollapsedLines = 2;

  @override
  Widget build(BuildContext context) {
    // Priority is carried by the row's own tint rather than a separate chip.
    final appearance = context.watch<TaskProvider>();
    final priority = appearance.colorForPriority(widget.task.priority);
    final priorityStyle = appearance.priorityColorStyle;
    final cardColor = switch (priorityStyle) {
      PriorityColorStyle.fill => priority.withValues(alpha: 0.20),
      _ => appearance.backgroundColor,
    };
    final cardBorder = switch (priorityStyle) {
      PriorityColorStyle.outline => Border.all(color: priority, width: 3.5),
      PriorityColorStyle.fill => Border.all(
        color: priority.withValues(alpha: 0.20),
      ),
      _ => Border.all(color: const Color(0xFFE4E8F0)),
    };
    final metadataColor = priorityStyle == PriorityColorStyle.textBackground
        ? priority
        : const Color(0xFF475569);
    final selectedTime = widget.task.timeForDay(widget.selectedDay);
    // A reminder that has already fired, on a widget.task still not done. The badge
    // on the app icon says how many need attention; this is what says which.
    final reminderOverdue =
        widget.task.reminderMinutesBefore != null &&
        !widget.task.isDoneOn(widget.selectedDay) &&
        selectedTime != null &&
        !widget.task.acknowledgedReminderDays.contains(
          PlannerTask.calendarDayKey(dateOnly(widget.selectedDay)),
        ) &&
        DateTime(
              widget.selectedDay.year,
              widget.selectedDay.month,
              widget.selectedDay.day,
              selectedTime.hour,
              selectedTime.minute,
            )
            .subtract(Duration(minutes: widget.task.reminderMinutesBefore!))
            .isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        // Keyed by task so a half-open row does not stay open over whichever
        // task happens to take its place after a reorder or a filter change.
        key: ValueKey(widget.task.id),
        groupTag: 'task',
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onToggle(),
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              icon: widget.task.isDoneOn(widget.selectedDay)
                  ? Icons.undo
                  : Icons.check,
              label: widget.task.isDoneOn(widget.selectedDay)
                  ? context.tr('未完成', 'Undo')
                  : context.tr('完成', 'Done'),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onDelete(),
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: context.tr('刪除', 'Delete'),
            ),
          ],
        ),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            // The row itself opens the widget.task: edit and delete both live in that
            // sheet, so a pair of buttons on every row was spending permanent
            // space on something one tap already reaches.
            onTap: widget.onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: cardBorder,
              ),
              child: ConstrainedBox(
                // A one-line task is only about 34px tall, which makes a poor
                // swipe target — the gesture needs somewhere to start. The
                // floor costs nothing on taller rows.
                constraints: const BoxConstraints(minHeight: 58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 4, 4),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            // Scaled rather than just boxed smaller: Checkbox
                            // draws at a fixed size, so shrinking the box alone
                            // clips it instead of making it smaller. Swiping
                            // right also completes a task, so the tick box can
                            // afford to be a modest target rather than a
                            // full-size one.
                            child: Transform.scale(
                              scale: 0.8,
                              child: Checkbox(
                                value: widget.task.isDoneOn(
                                  widget.selectedDay,
                                ),
                                onChanged: (_) => widget.onToggle(),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color:
                                          priorityStyle ==
                                              PriorityColorStyle.textBackground
                                          ? priority.withValues(alpha: 0.20)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 0,
                                      children: [
                                        if (widget.task.category.isNotEmpty)
                                          MetaChip(
                                            icon: Icons.label_outline,
                                            label: localizedTaskCategory(
                                              widget.task.category,
                                              english: context.isEnglish,
                                            ),
                                            color: metadataColor,
                                            transparentBackground:
                                                priorityStyle ==
                                                PriorityColorStyle
                                                    .textBackground,
                                          ),
                                        Text(
                                          widget.task.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    priorityStyle ==
                                                        PriorityColorStyle
                                                            .textOnly
                                                    ? priority
                                                    : null,
                                                decoration: widget.task.isDone
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                decorationThickness:
                                                    widget.task.isDone
                                                    ? 2.5
                                                    : null,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        // Date and time read as one unit, so they stay
                                        // adjacent; priority trails them.
                                        // A span is one thing lasting a while, so it
                                        // reads as a range plus where today sits in
                                        // it — not as a count of occurrences.
                                        MetaChip(
                                          icon: widget.task.isSpan
                                              ? Icons.date_range
                                              : Icons.event_repeat,
                                          label: widget.task.isSpan
                                              ? spanLabel(widget.task.days)
                                              : assignedDaysLabel(
                                                  widget.task.days,
                                                  english: context.isEnglish,
                                                ),
                                          color: metadataColor,
                                          transparentBackground:
                                              priorityStyle ==
                                              PriorityColorStyle.textBackground,
                                        ),
                                        if (widget.task.isSpan &&
                                            widget.task.days.length > 1)
                                          MetaChip(
                                            icon: Icons.timelapse,
                                            label: spanProgressLabel(
                                              widget.task.days,
                                              widget.selectedDay,
                                              english: context.isEnglish,
                                            ),
                                            color: metadataColor,
                                            transparentBackground:
                                                priorityStyle ==
                                                PriorityColorStyle
                                                    .textBackground,
                                          ),
                                        if (selectedTime != null)
                                          MetaChip(
                                            icon: Icons.schedule,
                                            label: selectedTime.format(context),
                                            color: metadataColor,
                                            transparentBackground:
                                                priorityStyle ==
                                                PriorityColorStyle
                                                    .textBackground,
                                          ),
                                        if (reminderOverdue)
                                          // Tapping clears it: the mark is an alert to
                                          // be seen, not a state of the widget.task, so it is
                                          // dismissed on its own rather than by
                                          // completing the widget.task.
                                          InkWell(
                                            onTap: () => context
                                                .read<TaskProvider>()
                                                .acknowledgeReminder(
                                                  widget.task,
                                                  widget.selectedDay,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: Text(
                                                '!',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  height: 1,
                                                  fontWeight: FontWeight.w900,
                                                  color: appearance
                                                      .colorForPriority(
                                                        TaskPriority.high,
                                                      ),
                                                ),
                                                semanticsLabel: context.tr(
                                                  '提醒已過時間，點擊即可清除',
                                                  'Reminder overdue — tap to dismiss',
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (widget.task.reminderMinutesBefore !=
                                                null &&
                                            selectedTime != null)
                                          MetaChip(
                                            icon: Icons
                                                .notifications_active_outlined,
                                            label: reminderLeadLabel(
                                              context,
                                              widget.task.reminderMinutesBefore,
                                            ),
                                            color: metadataColor,
                                            transparentBackground:
                                                priorityStyle ==
                                                PriorityColorStyle
                                                    .textBackground,
                                          ),
                                        MetaChip(
                                          icon: Icons.flag,
                                          label: widget.task.priority
                                              .localizedLabel(
                                                english: context.isEnglish,
                                              ),
                                          color: priority,
                                          transparentBackground:
                                              priorityStyle ==
                                              PriorityColorStyle.textBackground,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.task.notes.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  // Measured rather than guessed: 'show more'
                                  // only earns its place when the text really is
                                  // cut off, so a one-line note has no stray
                                  // control under it.
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final noteStyle = TextStyle(
                                        fontSize: 12,
                                        color:
                                            priorityStyle ==
                                                PriorityColorStyle.textOnly
                                            ? priority
                                            : const Color(0xFF586174),
                                        backgroundColor:
                                            priorityStyle ==
                                                PriorityColorStyle
                                                    .textBackground
                                            ? priority.withValues(alpha: 0.20)
                                            : null,
                                      );
                                      final painter = TextPainter(
                                        text: TextSpan(
                                          text: widget.task.notes,
                                          style: noteStyle,
                                        ),
                                        maxLines: _notesCollapsedLines,
                                        textDirection: TextDirection.ltr,
                                      )..layout(maxWidth: constraints.maxWidth);
                                      final overflows =
                                          painter.didExceedMaxLines;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LinkifiedText(
                                            widget.task.notes,
                                            style: noteStyle,
                                            maxLines: _notesExpanded
                                                ? null
                                                : _notesCollapsedLines,
                                            overflow: _notesExpanded
                                                ? TextOverflow.clip
                                                : TextOverflow.ellipsis,
                                          ),
                                          if (overflows)
                                            GestureDetector(
                                              onTap: () => setState(
                                                () => _notesExpanded =
                                                    !_notesExpanded,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  _notesExpanded
                                                      ? context.tr(
                                                          '收合',
                                                          'Show less',
                                                        )
                                                      : context.tr(
                                                          '顯示更多',
                                                          'Show more',
                                                        ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = const Color(0xFF475569),
    this.transparentBackground = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: transparentBackground
            ? Colors.transparent
            : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyTaskState extends StatelessWidget {
  const EmptyTaskState({super.key});

  @override
  Widget build(BuildContext context) {
    final background = context.watch<TaskProvider>().backgroundColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('這天沒有任務', 'No tasks for this day'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              '休息也是很棒的！或找前後幾天的事情來做！',
              'Taking a break is great too, or check nearby days for tasks.',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
