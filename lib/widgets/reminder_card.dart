import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../screens/reminder_details_screen.dart';
import '../utils/app_theme.dart';

class ReminderCard extends StatefulWidget {
  final Reminder reminder;
  final VoidCallback onEdit;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onEdit,
  });

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getPriorityColor() {
    switch (widget.reminder.priority) {
      case ReminderPriority.low:
        return AppColors.periwinkle;
      case ReminderPriority.medium:
        return AppColors.warning;
      case ReminderPriority.high:
        return AppColors.error;
    }
  }

  String _getPriorityText() {
    return widget.reminder.priority.toString().split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor();

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: priorityColor.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // "Sticky note" signature shape: three soft corners + one clipped
        // corner, like a note peeled off a pad — distinguishes SmartSpot's
        // reminders from a generic flat list row.
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? AppColors.surfaceDark : Colors.white,
                isDark ? AppColors.creamBackgroundDark : priorityColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(8),
            ),
            border: Border.all(
              color: priorityColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: priorityColor.withValues(alpha: 0.1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(8),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReminderDetailsScreen(reminder: widget.reminder),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Title, Category, Priority
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Priority Indicator
                          Container(
                            width: 4,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  priorityColor,
                                  priorityColor.withValues(alpha: 0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.reminder.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: widget.reminder.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: Colors.grey[400],
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.15),
                                        AppColors.primaryLight.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.reminder.categoryEmoji} ${widget.reminder.category.toString().split('.').last}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  priorityColor,
                                  priorityColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: priorityColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _getPriorityText(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description (if available)
                      if (widget.reminder.description != null &&
                          widget.reminder.description!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reminder.description!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),

                      // Location Info
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[800]?.withValues(alpha: 0.5)
                              : Colors.grey[100]?.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.reminder.locationName ?? 'Location set',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.reminder.radius.toInt()}m',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Due Date (if available)
                      if (widget.reminder.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.reminder.formattedDate,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Repeat schedule (recurring reminders only)
                      if (widget.reminder.isRecurring)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.repeat_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.reminder.repeatLabel,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionButton(
                            context,
                            widget.reminder.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                            widget.reminder.isCompleted ? 'Done' : 'Complete',
                            widget.reminder.isCompleted ? AppColors.success : Colors.grey,
                                () {
                              context.read<ReminderProvider>().toggleCompletion(widget.reminder.id);
                            },
                          ),
                          const SizedBox(width: 6),
                          _buildActionButton(
                            context,
                            Icons.edit_rounded,
                            'Edit',
                            AppColors.info,
                            widget.onEdit,
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.grey[600],
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'archive',
                                child: const Text('Archive'),
                                onTap: () {
                                  context.read<ReminderProvider>().archiveReminder(widget.reminder.id);
                                },
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => _buildDeleteDialog(context),
                                  );
                                },
                              ),
                            ],
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

  Widget _buildActionButton(
      BuildContext context,
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteDialog(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.error, Color(0xFFF6A5A7)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Reminder?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.error, Color(0xFFF6A5A7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.read<ReminderProvider>().deleteReminder(widget.reminder.id);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Delete',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}