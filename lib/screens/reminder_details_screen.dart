import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/live_geofence_preview_card.dart';
import 'add_reminder_screen.dart';

class ReminderDetailsScreen extends StatelessWidget {
  final Reminder reminder;

  const ReminderDetailsScreen({super.key, required this.reminder});

  Color _priorityColor(ReminderPriority p) {
    switch (p) {
      case ReminderPriority.low:
        return AppColors.info;
      case ReminderPriority.medium:
        return AppColors.warning;
      case ReminderPriority.high:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _priorityColor(reminder.priority);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddReminderScreen(reminder: reminder),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text(reminder.categoryEmoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reminder.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            reminder.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(reminder.priority.toString().split('.').last.toUpperCase()),
                backgroundColor: color.withValues(alpha: 0.12),
                labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(reminder.category.toString().split('.').last.toUpperCase()),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              if (reminder.isCompleted)
                Chip(
                  label: const Text('COMPLETED'),
                  backgroundColor: AppColors.success.withValues(alpha: 0.18),
                  labelStyle: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              if (reminder.isArchived)
                Chip(
                  label: const Text('ARCHIVED'),
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[200] : const Color(0xFF2D3142),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (reminder.description != null && reminder.description!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Description', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              reminder.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: 24),
          Text('Location & Geofence Preview', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          LiveGeofencePreviewCard(reminder: reminder),
          if (reminder.dueDate != null) ...[
            const SizedBox(height: 24),
            Text('Due Date', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(reminder.formattedDate),
              ],
            ),
          ],
          if (reminder.isRecurring) ...[
            const SizedBox(height: 24),
            Text('Repeat', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(reminder.repeatLabel),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Created', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            '${reminder.createdAt.day}/${reminder.createdAt.month}/${reminder.createdAt.year}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ReminderProvider>().toggleCompletion(reminder.id);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: Icon(
                    reminder.isCompleted ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                  ),
                  label: Text(reminder.isCompleted ? 'Mark Pending' : 'Mark Complete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<ReminderProvider>().archiveReminder(reminder.id);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete Reminder'),
                    content: const Text('Are you sure you want to delete this reminder?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<ReminderProvider>().deleteReminder(reminder.id);
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                        },
                        child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: const Text('Delete Reminder', style: TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
