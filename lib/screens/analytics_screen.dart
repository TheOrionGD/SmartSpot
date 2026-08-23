import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../services/intelligence_service.dart';
import '../utils/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const _categoryColors = {
    ReminderCategory.shopping: AppColors.info,
    ReminderCategory.home: AppColors.success,
    ReminderCategory.office: AppColors.info,
    ReminderCategory.college: Color(0xFFE8639B),
    ReminderCategory.health: AppColors.error,
    ReminderCategory.travel: Color(0xFF00B4D8),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReminderProvider>();
      provider.loadReminders();
      provider.loadStatistics();
      provider.loadArchived();
    });
  }

  String _label(ReminderCategory c) {
    final name = c.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final all = provider.allReminders;
          final stats = provider.statistics;
          final archivedCount = provider.archivedReminders.length;

          final Map<ReminderCategory, int> categoryCounts = {
            for (final c in ReminderCategory.values) c: 0,
          };
          for (final r in all) {
            categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
          }
          final totalForPie = categoryCounts.values.fold<int>(0, (a, b) => a + b);

          final weeklyCounts = List<int>.filled(7, 0);
          final now = DateTime.now();
          for (final r in all) {
            final diff = now.difference(r.createdAt).inDays;
            if (diff >= 0 && diff < 7) {
              weeklyCounts[6 - diff]++;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadReminders();
              await provider.loadStatistics();
              await provider.loadArchived();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _statCard('Total', '${stats['total'] ?? 0}', AppColors.primary, Icons.list_alt_rounded),
                    _statCard('Pending', '${stats['pending'] ?? 0}', AppColors.warning, Icons.pending_actions_rounded),
                    _statCard('Completed', '${stats['completed'] ?? 0}', AppColors.success, Icons.check_circle_rounded),
                    _statCard('Archived', '$archivedCount', Colors.grey, Icons.archive_rounded),
                  ],
                ),
                const SizedBox(height: 20),
                const _InsightsPanel(),
                const SizedBox(height: 28),
                Text('Category Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (totalForPie == 0)
                  _emptyChartPlaceholder('No reminders yet to analyze')
                else
                  SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                for (final entry in categoryCounts.entries)
                                  if (entry.value > 0)
                                    PieChartSectionData(
                                      value: entry.value.toDouble(),
                                      title: '${entry.value}',
                                      color: _categoryColors[entry.key] ?? Colors.grey,
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final entry in categoryCounts.entries)
                                if (entry.value > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _categoryColors[entry.key] ?? Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _label(entry.key),
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 28),
                Text('Reminders Created (Last 7 Days)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (weeklyCounts.isEmpty ? 1 : weeklyCounts.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final day = now.subtract(Duration(days: 6 - value.toInt()));
                              const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[(day.weekday - 1) % 7],
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: [
                        for (int i = 0; i < weeklyCounts.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyCounts[i].toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('Completion Rate by Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'How consistently you finish reminders in each category',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (totalForPie == 0)
                  _emptyChartPlaceholder('No reminders yet to analyze')
                else
                  ..._buildCompletionRows(all, categoryCounts),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCompletionRows(
    List<Reminder> all,
    Map<ReminderCategory, int> categoryCounts,
  ) {
    final rows = <Widget>[];
    for (final entry in categoryCounts.entries) {
      if (entry.value == 0) continue;
      final completed = all
          .where((r) => r.category == entry.key && r.isCompleted)
          .length;
      final rate = completed / entry.value;
      final color = _categoryColors[entry.key] ?? Colors.grey;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_label(entry.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(
                    '$completed / ${entry.value} · ${(rate * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppColors.cardShadow(color, alpha: 0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.softGradient(color),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChartPlaceholder(String message) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600])),
    );
  }
}

/// Feature 15 — Personalized Productivity Insights.
/// "You complete 82% of your college reminders but only 54% of shopping
/// ones. Consider setting shopping reminders with a larger radius."
class _InsightsPanel extends StatefulWidget {
  const _InsightsPanel();

  @override
  State<_InsightsPanel> createState() => _InsightsPanelState();
}

class _InsightsPanelState extends State<_InsightsPanel> {
  List<Insight>? _insights;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final insights = await context.read<ReminderProvider>().getInsights();
    if (mounted) setState(() => _insights = insights);
  }

  @override
  Widget build(BuildContext context) {
    final insights = _insights;
    if (insights == null || insights.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Your SmartSpot Insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight.text,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
