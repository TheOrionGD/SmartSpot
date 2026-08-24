import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_translations.dart';
import '../utils/app_motion.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import '../widgets/category_filter.dart';
import '../widgets/smart_suggestion_card.dart';
import 'add_reminder_screen.dart';
import 'archive_screen.dart';
import 'login_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  late ScrollController _scrollController;
  bool _isSearchFocused = false;
  double _scrollOffset = 0.0;
  bool _isFabOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController();

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset.clamp(0.0, 100.0);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openAddReminderScreen() {
    setState(() => _isFabOpen = true);
    Navigator.push(
      context,
      AppPageRoute(builder: (_) => const AddReminderScreen()),
    ).then((_) {
      if (mounted) {
        setState(() => _isFabOpen = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);
    final headerAlpha = (_scrollOffset / 80.0).clamp(0.0, 0.95);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AnimatedScale(
          scale: 1.0 - (_scrollOffset * 0.0015).clamp(0.0, 0.08),
          duration: animate ? AppMotion.micro : Duration.zero,
          child: const Text(
            'SmartSpot',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: (isDark ? AppColors.surfaceDark : AppColors.primaryDark)
            .withValues(alpha: headerAlpha),
        flexibleSpace: headerAlpha > 0.1
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              )
            : null,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: AnimatedContainer(
              duration: animate ? AppMotion.micro : Duration.zero,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18 + (headerAlpha * 0.1)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildMenu(context),
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.creamBackgroundDark : AppColors.creamBackground,
        ),
        child: Consumer<ReminderProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: () => provider.initialize(),
              color: AppColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildPremiumStatisticsSection(context, provider),
                        const SizedBox(height: 20),
                        const SmartSuggestionsSection(),
                        const MissedReminderSection(),
                        const SizedBox(height: 4),
                        _buildSearchBar(context, provider),
                        const SizedBox(height: 16),
                        const CategoryFilter(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  if (provider.isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildSkeletonList(),
                      ),
                    )
                  else if (provider.filteredReminders.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reminder = provider.filteredReminders[index];

                            return TweenAnimationBuilder<double>(
                              key: ValueKey(reminder.id),
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: animate
                                  ? Duration(milliseconds: 200 + (index * 30).clamp(0, 240))
                                  : Duration.zero,
                              curve: AppMotion.screenCurve,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1.0 - value) * 12.0),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: ReminderCard(
                                  reminder: reminder,
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      AppPageRoute(
                                        builder: (_) => AddReminderScreen(reminder: reminder),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          childCount: provider.filteredReminders.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: _buildAnimatedFAB(context),
    );
  }

  Widget _buildAnimatedFAB(BuildContext context) {
    final animate = AppMotion.shouldAnimate(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _isFabOpen ? 1.0 : 0.0),
      duration: animate ? AppMotion.component : Duration.zero,
      curve: AppMotion.springCurve,
      builder: (context, rotationVal, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _openAddReminderScreen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Transform.rotate(
                  angle: rotationVal * 0.785398, // ~45 degrees (pi / 4)
                  child: const Icon(
                    Icons.add_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumStatisticsSection(BuildContext context, ReminderProvider provider) {
    final stats = provider.statistics;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Overview',
            style: AppTypography.body(
              fontSize: 13,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedCounterText(
            value: (stats['total'] ?? 0).toDouble(),
            formatter: (val) => val.toInt().toString(),
            style: AppTypography.display(fontSize: 44, weight: FontWeight.w800, color: Colors.white),
          ),
          Text(
            'reminders total',
            style: AppTypography.body(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildGlassStatChip(context, 'Pending', (stats['pending'] ?? 0).toDouble(), Icons.schedule_rounded),
              const SizedBox(width: 10),
              _buildGlassStatChip(context, 'Done', (stats['completed'] ?? 0).toDouble(), Icons.check_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatChip(BuildContext context, String label, double value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCounterText(
                  value: value,
                  formatter: (val) => val.toInt().toString(),
                  style: AppTypography.body(fontSize: 15, weight: FontWeight.w800, color: Colors.white),
                ),
                Text(label, style: AppTypography.body(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ReminderProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);

    return AnimatedContainer(
      duration: animate ? AppMotion.component : Duration.zero,
      curve: AppMotion.easeOutSmooth,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isSearchFocused
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.25),
          width: _isSearchFocused ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isSearchFocused
                ? AppColors.primary.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: _isSearchFocused ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (query) {
            provider.searchReminders(query);
          },
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            hintText: AppTranslations.tr(context, 'search_hint'),
            prefixIcon: AnimatedScale(
              scale: _isSearchFocused ? 1.1 : 1.0,
              duration: animate ? AppMotion.micro : Duration.zero,
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.primary, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      provider.searchReminders('');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(4, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppSkeletonShimmer(
          width: double.infinity,
          height: 100,
          borderRadius: 20,
        ),
      )),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryLight.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reminders Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first location-based reminder',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openAddReminderScreen,
                  borderRadius: BorderRadius.circular(18),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: Text(
                      'Create Reminder',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            context,
            Icons.star_rounded,
            'Favorite Locations',
            'Manage your saved places',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                AppPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          _buildMenuTile(
            context,
            Icons.archive_rounded,
            'Archived Reminders',
            'View all archived items',
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                AppPageRoute(builder: (_) => const ArchiveScreen()),
              );
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          _buildMenuTile(
            context,
            Icons.logout_rounded,
            'Logout',
            'Sign out of your account',
            () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                AppPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}