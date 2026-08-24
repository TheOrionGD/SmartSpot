import 'package:flutter/material.dart';
import '../models/reminder_condition.dart';
import '../utils/app_theme.dart';

/// Feature 3 — Multi-Condition Reminders.
/// Lets the user AND-combine extra trigger conditions on top of the base
/// geofence, e.g. "College AND after 8 AM AND if raining".
class MultiConditionBuilder extends StatelessWidget {
  final List<ReminderCondition> conditions;
  final ValueChanged<List<ReminderCondition>> onChanged;

  const MultiConditionBuilder({
    super.key,
    required this.conditions,
    required this.onChanged,
  });

  void _add(ReminderCondition c) => onChanged([...conditions, c]);
  void _removeAt(int i) => onChanged([...conditions]..removeAt(i));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conditions.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < conditions.length; i++)
                Chip(
                  label: Text(
                    conditions[i].label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.15),
                  side: BorderSide(
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                    width: 1.2,
                  ),
                  deleteIcon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? Colors.white : AppColors.primaryDark,
                  ),
                  onDeleted: () => _removeAt(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _addButton(context, 'Time after…', Icons.schedule_rounded, () => _pickTime(context, isAfter: true)),
            _addButton(context, 'Time before…', Icons.schedule_rounded, () => _pickTime(context, isAfter: false)),
            _addButton(context, 'Specific day…', Icons.calendar_today_rounded, () => _pickDay(context)),
            _addButton(context, 'If raining', Icons.water_drop_rounded, () => _add(ReminderCondition.rain())),
            _addButton(context, 'If clear', Icons.wb_sunny_rounded, () => _add(ReminderCondition.clear())),
            _addButton(context, "Heading there", Icons.alt_route_rounded, () => _add(ReminderCondition.approaching())),
          ],
        ),
      ],
    );
  }

  Widget _addButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 15,
        color: isDark ? AppColors.primaryLight : AppColors.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white : const Color(0xFF10131C),
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? AppColors.primaryLight : AppColors.primaryDark,
        backgroundColor: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.08),
        side: BorderSide(
          color: isDark
              ? AppColors.primaryLight.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, {required bool isAfter}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isAfter ? 8 : 20, minute: 0),
    );
    if (picked == null) return;
    _add(isAfter
        ? ReminderCondition.timeAfter(picked.hour, picked.minute)
        : ReminderCondition.timeBefore(picked.hour, picked.minute));
  }

  Future<void> _pickDay(BuildContext context) async {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (var i = 0; i < days.length; i++)
              ListTile(
                title: Text(days[i]),
                onTap: () => Navigator.pop(ctx, i + 1),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _add(ReminderCondition.onDay(picked));
  }
}
