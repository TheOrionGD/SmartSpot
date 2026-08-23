import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import 'reminder_details_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadArchived();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Reminders')),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final items = provider.archivedReminders;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No archived reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadArchived,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final reminder = items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: Text(reminder.categoryEmoji, style: const TextStyle(fontSize: 24)),
                    title: Text(reminder.title),
                    subtitle: Text(reminder.locationName ?? 'Location set'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderDetailsScreen(reminder: reminder),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.unarchive_outlined, color: AppColors.primary),
                          tooltip: 'Restore',
                          onPressed: () {
                            context.read<ReminderProvider>().restoreReminder(reminder.id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () {
                            context.read<ReminderProvider>().deleteReminder(reminder.id);
                          },
                        ),
                      ],
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
