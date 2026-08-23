import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  String _getCategoryEmoji(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.shopping:
        return '🛒';
      case ReminderCategory.home:
        return '🏠';
      case ReminderCategory.office:
        return '💼';
      case ReminderCategory.college:
        return '🎓';
      case ReminderCategory.health:
        return '💊';
      case ReminderCategory.travel:
        return '🚗';
    }
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : LinearGradient(
          colors: [
            isDark
                ? Colors.grey[800]!
                : Colors.grey[100]!,
            isDark
                ? Colors.grey[900]!
                : Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : null,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}