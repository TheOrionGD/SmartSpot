import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';
import 'reminder_details_screen.dart';

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadCompleted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Completed Reminders')),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final items = provider.completedReminders;

          if (items.isEmpty) {
            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: animate ? AppMotion.component : Duration.zero,
                curve: AppMotion.easeOutSmooth,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.scale(
                      scale: 0.95 + (val * 0.05),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No completed reminders yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadCompleted,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final reminder = items[index];

                return TweenAnimationBuilder<double>(
                  key: ValueKey(reminder.id),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: animate ? AppMotion.component : Duration.zero,
                  curve: AppMotion.screenCurve,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1.0 - value) * 10.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: stickyNoteDecoration(
                      tint: AppColors.success,
                      isDark: isDark,
                      alpha: 0.08,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          reminder.title,
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[500],
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          reminder.locationName ?? 'Location set',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            AppPageRoute(
                              builder: (_) => ReminderDetailsScreen(reminder: reminder),
                            ),
                          );
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.replay_rounded, color: AppColors.primary),
                          tooltip: 'Mark as pending',
                          onPressed: () {
                            context.read<ReminderProvider>().toggleCompletion(reminder.id);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
