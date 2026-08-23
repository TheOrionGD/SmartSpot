import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'SmartSpot',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildMenu(context),
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Consumer<ReminderProvider>(
          builder: (context, provider, child) {
            return RefreshIndicator(
              onRefresh: () => provider.initialize(),
              color: AppColors.primary,
              child: CustomScrollView(
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
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: _buildPremiumLoader(),
                        ),
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
                            return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: ReminderCard(
                                  reminder: reminder,
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddReminderScreen(reminder: reminder),
                                      ),
                                    );
                                  },
                                )
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddReminderScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          tooltip: 'Add Reminder',
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
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
          Text(
            '${stats['total']}',
            style: AppTypography.display(fontSize: 44, weight: FontWeight.w800, color: Colors.white),
          ),
          Text(
            'reminders total',
            style: AppTypography.body(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildGlassStatChip(context, 'Pending', '${stats['pending']}', Icons.schedule_rounded),
              const SizedBox(width: 10),
              _buildGlassStatChip(context, 'Done', '${stats['completed']}', Icons.check_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatChip(BuildContext context, String label, String value, IconData icon) {
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
                Text(value, style: AppTypography.body(fontSize: 15, weight: FontWeight.w800, color: Colors.white)),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (query) {
          provider.searchReminders(query);
        },
        decoration: InputDecoration(
          hintText: 'Search reminders...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.primary),
            onPressed: () {
              _searchController.clear();
              provider.searchReminders('');
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.2).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading your reminders...',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
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
            child: Icon(
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddReminderScreen(),
                    ),
                  );
                },
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
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
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
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
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
                MaterialPageRoute(builder: (_) => const LoginScreen()),
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