import 'package:flutter/material.dart';

import '../localization/app_locale.dart';
import '../models/planner_task.dart';

/// Category chips with a “+” to add and long-press to remove.
///
/// The list is the user's own, stored in Firestore, so additions and removals
/// persist across devices.
class TaskCategoryField extends StatefulWidget {
  const TaskCategoryField({
    super.key,
    required this.category,
    required this.categories,
    required this.onChanged,
    required this.onAddCategory,
    required this.onRemoveCategory,
  });

  /// Current value: one of [categories], or '' for none.
  final String category;

  /// The user's saved categories.
  final List<String> categories;

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onAddCategory;
  final ValueChanged<String> onRemoveCategory;

  @override
  State<TaskCategoryField> createState() => _TaskCategoryFieldState();
}

class _TaskCategoryFieldState extends State<TaskCategoryField> {
  /// Local working copy, so add/remove show instantly rather than waiting for
  /// the Firestore round-trip.
  late List<String> _categories = [...widget.categories];

  /// The chip currently showing its remove button, set by long-press.
  String? _removing;

  @override
  void didUpdateWidget(TaskCategoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt the saved list once it arrives, but keep anything added locally
    // that hasn't round-tripped yet.
    if (widget.categories != oldWidget.categories) {
      final incoming = [...widget.categories];
      for (final local in _categories) {
        if (!incoming.contains(local)) incoming.add(local);
      }
      _categories = incoming;
    }
  }

  List<String> get _visible => [
    ..._categories,
    // A task's existing category always stays visible, even if it was since
    // removed from the list.
    if (widget.category.isNotEmpty && !_categories.contains(widget.category))
      widget.category,
  ];

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('新增分類', 'Add category')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('分類名稱', 'Category name'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.tr('新增', 'Add')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      if (!_categories.contains(name)) _categories.add(name);
      _removing = null;
    });
    widget.onAddCategory(name);
    // A newly added category is selected straight away — that's why it was
    // added.
    widget.onChanged(name);
  }

  void _remove(String category) {
    setState(() {
      _categories.remove(category);
      _removing = null;
    });
    widget.onRemoveCategory(category);
    // Removing the selected category leaves the task without one.
    if (widget.category == category) widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.tr('分類', 'Category'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_removing != null)
                  Expanded(
                    child: Text(
                      context.tr('點選 − 移除分類', 'Tap − to remove category'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9AA4B2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in _visible)
                  GestureDetector(
                    onLongPress: () => setState(() => _removing = category),
                    child: InputChip(
                      label: Text(
                        localizedTaskCategory(
                          category,
                          english: context.isEnglish,
                        ),
                      ),
                      selected: widget.category == category,
                      showCheckmark: false,
                      onPressed: () {
                        if (_removing != null) {
                          // Any tap while a remove button is showing just
                          // dismisses it — safer than deleting on a mis-tap.
                          setState(() => _removing = null);
                          return;
                        }
                        widget.onChanged(
                          widget.category == category ? '' : category,
                        );
                      },
                      onDeleted: _removing == category
                          ? () => _remove(category)
                          : null,
                      deleteIcon: const Icon(
                        Icons.remove_circle,
                        size: 18,
                        color: Color(0xFFE10600),
                      ),
                      deleteButtonTooltipMessage: context.tr(
                        '移除分類',
                        'Remove category',
                      ),
                    ),
                  ),
                IconButton.outlined(
                  tooltip: context.tr('新增分類', 'Add category'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _addCategory,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
