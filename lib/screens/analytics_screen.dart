import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../services/intelligence_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_translations.dart';
import '../utils/app_motion.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.tr(context, 'analytics'))),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final all = provider.allReminders;
          final stats = provider.statistics;
          final archivedCount = provider.archivedReminders.length;

          final total = stats['total'] ?? all.length;
          final completed = stats['completed'] ?? all.where((r) => r.isCompleted).length;
          final pending = stats['pending'] ?? all.where((r) => !r.isCompleted && !r.isArchived).length;

          // Category counts
          final Map<ReminderCategory, int> categoryCounts = {
            for (final c in ReminderCategory.values) c: 0,
          };
          for (final r in all) {
            categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
          }
          final totalForPie = categoryCounts.values.fold<int>(0, (a, b) => a + b);

          // Weekly created vs completed
          final weeklyCreated = List<int>.filled(7, 0);
          final weeklyCompleted = List<int>.filled(7, 0);
          final now = DateTime.now();
          for (final r in all) {
            final diffCreated = now.difference(r.createdAt).inDays;
            if (diffCreated >= 0 && diffCreated < 7) {
              weeklyCreated[6 - diffCreated]++;
            }
            if (r.isCompleted && r.lastCompletedAt != null) {
              final diffCompleted = now.difference(r.lastCompletedAt!).inDays;
              if (diffCompleted >= 0 && diffCompleted < 7) {
                weeklyCompleted[6 - diffCompleted]++;
              }
            }
          }

          // Priority breakdown
          int highCount = 0, medCount = 0, lowCount = 0;
          for (final r in all) {
            if (r.priority == ReminderPriority.high) {
              highCount++;
            } else if (r.priority == ReminderPriority.medium) {
              medCount++;
            } else {
              lowCount++;
            }
          }

          // Time of Day Breakdown (Morning, Afternoon, Evening, Night)
          int morning = 0, afternoon = 0, evening = 0, night = 0;
          for (final r in all) {
            final hour = r.createdAt.hour;
            if (hour >= 6 && hour < 12) {
              morning++;
            } else if (hour >= 12 && hour < 18) {
              afternoon++;
            } else if (hour >= 18 && hour < 22) {
              evening++;
            } else {
              night++;
            }
          }

          // Top location spots
          final Map<String, int> locationMap = {};
          for (final r in all) {
            final locName = r.locationName;
            final loc = (locName != null && locName.trim().isNotEmpty)
                ? locName.trim()
                : 'Current Location';
            locationMap[loc] = (locationMap[loc] ?? 0) + 1;
          }
          final sortedLocations = locationMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final topLocations = sortedLocations.take(4).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadReminders();
              await provider.loadStatistics();
              await provider.loadArchived();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -------------------------------------------------------------
                // WAY 1: Core KPI Metric Cards & Productivity Grade
                // -------------------------------------------------------------
                _sectionHeader(context, '1. ${AppTranslations.tr(context, 'kpi_summary')}', Icons.space_dashboard_rounded),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _statCard(AppTranslations.tr(context, 'total'), total.toDouble(), AppColors.primary, Icons.list_alt_rounded),
                    _statCard(AppTranslations.tr(context, 'pending'), pending.toDouble(), AppColors.warning, Icons.pending_actions_rounded),
                    _statCard(AppTranslations.tr(context, 'completed'), completed.toDouble(), AppColors.success, Icons.check_circle_rounded),
                    _statCard(AppTranslations.tr(context, 'archived'), archivedCount.toDouble(), Colors.grey, Icons.archive_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Completion Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            AnimatedCounterText(
                              value: total > 0 ? (completed / total * 100) : 0.0,
                              formatter: (val) => '${val.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          total > 0 && (completed / total) >= 0.7 ? 'Grade A+' : 'Grade B',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 2: Category Distribution Donut Chart
                // -------------------------------------------------------------
                _sectionHeader(context, '2. ${AppTranslations.tr(context, 'category_dist')}', Icons.pie_chart_rounded),
                const SizedBox(height: 12),
                if (totalForPie == 0)
                  _emptyChartPlaceholder('No reminders yet for category analysis')
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(isDark),
                    child: SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 36,
                                sections: [
                                  for (final entry in categoryCounts.entries)
                                    if (entry.value > 0)
                                      PieChartSectionData(
                                        value: entry.value.toDouble(),
                                        title: '${(entry.value / totalForPie * 100).toStringAsFixed(0)}%',
                                        color: _categoryColors[entry.key] ?? Colors.grey,
                                        radius: 54,
                                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                  ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 3: 7-Day Activity Creation & Completion Trend
                // -------------------------------------------------------------
                _sectionHeader(context, '3. ${AppTranslations.tr(context, 'weekly_trend')}', Icons.bar_chart_rounded),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(isDark),
                  child: SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (weeklyCreated.isEmpty ? 1 : weeklyCreated.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
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
                          for (int i = 0; i < 7; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: weeklyCreated[i].toDouble(),
                                  color: AppColors.primary,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: weeklyCompleted[i].toDouble(),
                                  color: AppColors.sage,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 4: Category Completion Consistency Bars
                // -------------------------------------------------------------
                _sectionHeader(context, '4. Category Completion Consistency', Icons.align_horizontal_left_rounded),
                const SizedBox(height: 12),
                if (totalForPie == 0)
                  _emptyChartPlaceholder('No data available yet')
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(isDark),
                    child: Column(
                      children: _buildCompletionRows(all, categoryCounts),
                    ),
                  ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 5: Priority Level Breakdown
                // -------------------------------------------------------------
                _sectionHeader(context, '5. ${AppTranslations.tr(context, 'priority_breakdown')}', Icons.flag_rounded),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(isDark),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _priorityBadge('High', '$highCount', AppColors.error)),
                          const SizedBox(width: 8),
                          Expanded(child: _priorityBadge('Medium', '$medCount', AppColors.warning)),
                          const SizedBox(width: 8),
                          Expanded(child: _priorityBadge('Low', '$lowCount', AppColors.info)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              Expanded(flex: highCount > 0 ? highCount : 1, child: Container(color: AppColors.error)),
                              Expanded(flex: medCount > 0 ? medCount : 1, child: Container(color: AppColors.warning)),
                              Expanded(flex: lowCount > 0 ? lowCount : 1, child: Container(color: AppColors.info)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 6: Top Geofence Locations Analysis
                // -------------------------------------------------------------
                _sectionHeader(context, '6. ${AppTranslations.tr(context, 'top_locations')}', Icons.my_location_rounded),
                const SizedBox(height: 12),
                if (topLocations.isEmpty)
                  _emptyChartPlaceholder('No location spots registered')
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(isDark),
                    child: Column(
                      children: [
                        for (final entry in topLocations)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.place_rounded, color: AppColors.primary, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${entry.value} Reminders',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // -------------------------------------------------------------
                // WAY 7: Time-of-Day Activity & Smart Intelligence Scorecard
                // -------------------------------------------------------------
                _sectionHeader(context, '7. ${AppTranslations.tr(context, 'time_activity')} & ${AppTranslations.tr(context, 'smart_insights')}', Icons.auto_awesome_rounded),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Time-of-Day Creation Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _timeSegment('Morning', '$morning', Icons.wb_twilight_rounded, Colors.orange)),
                          Expanded(child: _timeSegment('Afternoon', '$afternoon', Icons.wb_sunny_rounded, Colors.amber)),
                          Expanded(child: _timeSegment('Evening', '$evening', Icons.nights_stay_rounded, Colors.indigo)),
                          Expanded(child: _timeSegment('Night', '$night', Icons.bedtime_rounded, Colors.purple)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      const _InsightsPanel(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _priorityBadge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _timeSegment(String label, String count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_label(entry.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _statCard(String label, double value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: AppColors.cardShadow(color, alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
                  AnimatedCounterText(
                    value: value,
                    formatter: (val) => val.toInt().toString(),
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
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    );
  }
}

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.text,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
