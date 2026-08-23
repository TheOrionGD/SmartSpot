import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../services/intelligence_service.dart';
import '../utils/app_theme.dart';

/// Feature 1 — Predictive Reminder Engine, surfaced on the home screen.
/// "You usually shop here on Saturdays. Create a grocery reminder?"
class SmartSuggestionsSection extends StatefulWidget {
  const SmartSuggestionsSection({super.key});

  @override
  State<SmartSuggestionsSection> createState() => _SmartSuggestionsSectionState();
}

class _SmartSuggestionsSectionState extends State<SmartSuggestionsSection> {
  List<SmartSuggestion>? _suggestions;
  final Set<int> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suggestions = await context.read<ReminderProvider>().getSmartSuggestions();
    if (mounted) setState(() => _suggestions = suggestions);
  }

  Future<void> _accept(SmartSuggestion s, int index) async {
    final provider = context.read<ReminderProvider>();
    await provider.addReminder(Reminder(
      id: '',
      title: '${s.category.name[0].toUpperCase()}${s.category.name.substring(1)} reminder',
      latitude: s.latitude,
      longitude: s.longitude,
      locationName: s.locationName,
      category: s.category,
      createdAt: DateTime.now(),
      repeatType: ReminderRepeatType.weekly,
    ));
    if (mounted) {
      setState(() => _dismissed.add(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Text('Reminder created from suggestion'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();

    final visible = <MapEntry<int, SmartSuggestion>>[
      for (var i = 0; i < suggestions.length; i++)
        if (!_dismissed.contains(i)) MapEntry(i, suggestions[i]),
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Smart Suggestions', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...visible.map((entry) {
            final index = entry.key;
            final s = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _dismissed.add(index)),
                              child: const Text('Dismiss'),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton(
                              onPressed: () => _accept(s, index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Feature 16/17 — Missed Reminder Prediction + Smart Rescheduling.
/// "You missed 'Buy groceries' 3 times. Reschedule for tomorrow at 6 PM?"
class MissedReminderSection extends StatefulWidget {
  const MissedReminderSection({super.key});

  @override
  State<MissedReminderSection> createState() => _MissedReminderSectionState();
}

class _MissedReminderSectionState extends State<MissedReminderSection> {
  List<MissedReminderSuggestion>? _suggestions;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final suggestions = await context.read<ReminderProvider>().getMissedReminderSuggestions();
    if (mounted) setState(() => _suggestions = suggestions);
  }

  Future<void> _reschedule(MissedReminderSuggestion s) async {
    await context.read<ReminderProvider>().applyMissedSuggestion(s);
    if (mounted) {
      setState(() => _dismissed.add(s.reminder.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Text('Reminder rescheduled'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions?.where((s) => !_dismissed.contains(s.reminder.id)).toList();
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Text('Keeps getting missed', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _dismissed.add(s.reminder.id)),
                                child: const Text('Not now'),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => _reschedule(s),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                child: const Text('Reschedule'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
