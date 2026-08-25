import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../utils/app_theme.dart';
import '../utils/permission_helper.dart';
import '../services/api_service.dart';

class _OnboardPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _hasForegroundLocation = false;
  bool _hasBackgroundLocation = false;
  bool _hasNotification = false;
  bool _isRequestingPermissions = false;

  bool get _allPermissionsGranted =>
      _hasForegroundLocation && (kIsWeb || _hasBackgroundLocation) && _hasNotification;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      icon: Icons.location_on_rounded,
      title: 'Welcome to SmartSpot',
      description:
          'A smarter way to remember what matters, right where it matters.',
      color: AppColors.primary,
    ),
    _OnboardPage(
      icon: Icons.gps_fixed_rounded,
      title: 'Location-Aware Geofencing',
      description:
          'SmartSpot uses GPS and geofencing to trigger reminders the moment '
          'you enter or leave a place you care about.',
      color: AppColors.info,
    ),
    _OnboardPage(
      icon: Icons.auto_awesome_rounded,
      title: 'AI Intelligence Engine',
      description:
          'SmartSpot predicts your next spots, adapts geofence radius to your movement speed, '
          'and prioritizes urgent tasks dynamically.',
      color: AppColors.sage,
    ),
    _OnboardPage(
      icon: Icons.tune_rounded,
      title: 'Multi-Condition Triggers',
      description:
          'Combine location with time of day, weather forecast, route direction, '
          'and activity recognition for pinpoint accuracy.',
      color: Color(0xFFFF9F43),
    ),
    _OnboardPage(
      icon: Icons.cloud_sync_rounded,
      title: 'Instant Cloud & Offline Sync',
      description:
          'Seamless background synchronization ensures your reminders are always ready '
          'across all your devices even when offline.',
      color: Color(0xFF00CEC9),
    ),
    _OnboardPage(
      icon: Icons.groups_rounded,
      title: 'Family & Group SmartSpots',
      description:
          'Share location spots with family members or team colleagues '
          'so everyone stays on top of shared tasks.',
      color: Color(0xFFE8639B),
    ),
    _OnboardPage(
      icon: Icons.verified_user_rounded,
      title: 'Permissions & Setup',
      description:
          'SmartSpot requires location, background tracking, and notification permissions '
          'to monitor perimeters and alert you with sound and vibration.',
      color: AppColors.periwinkle,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
    // Warm up backend server in background to compensate for cold boots
    ApiService.instance.pingBackend();
  }

  Future<void> _checkCurrentPermissions() async {
    final fgLoc = await PermissionHelper.hasLocationPermission();
    final bgLoc = await PermissionHelper.hasBackgroundLocationPermission();
    final notif = await PermissionHelper.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _hasForegroundLocation = fgLoc;
        _hasBackgroundLocation = bgLoc;
        _hasNotification = notif;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequestingPermissions = true);
    try {
      await PermissionHelper.requestAll(context);
    } finally {
      await _checkCurrentPermissions();
      if (mounted) setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _requestForegroundLocationAccess() async {
    setState(() => _isRequestingPermissions = true);
    try {
      await PermissionHelper.requestLocationPermission(context);
    } finally {
      await _checkCurrentPermissions();
      if (mounted) setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _requestBackgroundLocationAccess() async {
    setState(() => _isRequestingPermissions = true);
    try {
      if (!_hasForegroundLocation) {
        final granted = await PermissionHelper.requestLocationPermission(context);
        if (!granted || !mounted) return;
      }
      await PermissionHelper.requestBackgroundLocationPermission(context);
    } finally {
      await _checkCurrentPermissions();
      if (mounted) setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _requestNotificationAccess() async {
    setState(() => _isRequestingPermissions = true);
    try {
      await PermissionHelper.requestNotificationPermission(context);
    } finally {
      await _checkCurrentPermissions();
      if (mounted) setState(() => _isRequestingPermissions = false);
    }
  }

  Future<void> _handleGetStarted() async {
    if (!_allPermissionsGranted) {
      await _requestAllPermissions();
    }
    await _finish();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  if (index == _pages.length - 1) {
                    _checkCurrentPermissions();
                  }
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final isPermissionPage = index == _pages.length - 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 55, color: page.color),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                        ),
                        if (isPermissionPage) ...[
                          const SizedBox(height: 20),
                          if (!_allPermissionsGranted) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.security_rounded, size: 18),
                                label: const Text(
                                  'Grant All Permissions in One Tap',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: _isRequestingPermissions ? null : _requestAllPermissions,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _permissionTile(
                            title: 'Precise Location (GPS)',
                            subtitle: _hasForegroundLocation
                                ? 'Permission Granted'
                                : 'Detects when you arrive at or leave reminder spots',
                            icon: Icons.my_location_rounded,
                            isGranted: _hasForegroundLocation,
                            onTap: _isRequestingPermissions ? null : _requestForegroundLocationAccess,
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(height: 8),
                            _permissionTile(
                              title: 'Background Location',
                              subtitle: _hasBackgroundLocation
                                  ? 'Permission Granted'
                                  : 'Enables 24/7 geofence perimeter alerts in background',
                              icon: Icons.location_searching_rounded,
                              isGranted: _hasBackgroundLocation,
                              onTap: _isRequestingPermissions ? null : _requestBackgroundLocationAccess,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _permissionTile(
                            title: 'Notifications & Vibration',
                            subtitle: _hasNotification
                                ? 'Permission Granted'
                                : 'Delivers perimeter entry/exit pop-up alerts & vibration',
                            icon: Icons.notifications_active_rounded,
                            isGranted: _hasNotification,
                            onTap: _isRequestingPermissions ? null : _requestNotificationAccess,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? _pages[_currentPage].color
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        if (isLastPage) {
                          _handleGetStarted();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Center(
                        child: Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isGranted
            ? AppColors.sage.withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? AppColors.sage.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGranted
                ? AppColors.sage.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isGranted ? Icons.check_circle_rounded : icon,
            color: isGranted ? AppColors.sage : AppColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isGranted ? AppColors.sage : Colors.grey[600],
          ),
        ),
        trailing: isGranted
            ? const Icon(Icons.check_rounded, color: AppColors.sage)
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onTap,
                child: const Text('Allow', style: TextStyle(fontSize: 12)),
              ),
      ),
    );
  }
}
