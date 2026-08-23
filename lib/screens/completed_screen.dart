import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Completed Reminders')),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final items = provider.completedReminders;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No completed reminders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadCompleted,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final reminder = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    title: Text(
                      reminder.title,
                      style: const TextStyle(decoration: TextDecoration.lineThrough),
                    ),
                    subtitle: Text(reminder.locationName ?? 'Location set'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
