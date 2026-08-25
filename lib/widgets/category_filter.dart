import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  String _getCategoryEmoji(ReminderCategory category) {
    return Reminder(
      id: '',
      title: '',
      latitude: 0,
      longitude: 0,
      category: category,
      createdAt: DateTime.now(),
    ).categoryEmoji;
  }

  String _getCategoryName(ReminderCategory category) {
    return category.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // All Categories Filter
                _buildFilterChip(
                  context,
                  'All',
                  null,
                  provider.selectedCategory == null,
                  onSelected: (selected) {
                    provider.filterByCategory(null);
                  },
                ),
                const SizedBox(width: 8),
                // Individual Categories
                ...ReminderCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      context,
                      _getCategoryName(category),
                      _getCategoryEmoji(category),
                      provider.selectedCategory == category,
                      onSelected: (selected) {
                        if (selected) {
                          provider.filterByCategory(category);
                        } else {
                          provider.filterByCategory(null);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String? emoji,
    bool isSelected, {
    required Function(bool) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);

    return AnimatedContainer(
      duration: animate ? AppMotion.component : Duration.zero,
      curve: AppMotion.springCurve,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  isDark ? AppColors.surfaceDark : Colors.grey[100]!,
                  isDark ? AppColors.surfaceDark : Colors.grey[50]!,
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.primary.withValues(alpha: 0.18),
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(!isSelected),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  AnimatedScale(
                    scale: isSelected ? 1.12 : 1.0,
                    duration: animate ? AppMotion.micro : Duration.zero,
                    curve: AppMotion.springCurve,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedDefaultTextStyle(
                  duration: animate ? AppMotion.micro : Duration.zero,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : const Color(0xFF10131C)),
                    letterSpacing: 0.3,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}