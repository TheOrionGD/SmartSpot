import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/live_location_provider.dart';
import '../providers/reminder_provider.dart';
import '../screens/live_map_screen.dart';
import '../services/alarm_audio_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';

enum AlertPerimeterType {
  inside,
  outside,
  approaching,
  timeDue,
}

/// A dedicated full-screen dynamic perimeter alarm & alert screen.
/// Runs concurrent real hardware vibration and MP3 tune playback (vibration_sound.mp3),
/// featuring synchronized radar wave animations, live distance tracking,
/// and tap-to-silence controls.
class PerimeterAlertScreen extends StatefulWidget {
  final Reminder reminder;
  final AlertPerimeterType alertType;
  final double? edgeDistanceMeters;

  const PerimeterAlertScreen({
    super.key,
    required this.reminder,
    this.alertType = AlertPerimeterType.inside,
    this.edgeDistanceMeters,
  });

  static Future<void> show(
    BuildContext context, {
    required Reminder reminder,
    required AlertPerimeterType alertType,
    double? edgeDistanceMeters,
  }) {
    return Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => PerimeterAlertScreen(
          reminder: reminder,
          alertType: alertType,
          edgeDistanceMeters: edgeDistanceMeters,
        ),
      ),
    );
  }

  @override
  State<PerimeterAlertScreen> createState() => _PerimeterAlertScreenState();
}

class _PerimeterAlertScreenState extends State<PerimeterAlertScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  Timer? _clockTimer;
  DateTime _currentDateTime = DateTime.now();
  bool _isSilenced = false;

  Color get _accentColor {
    switch (widget.alertType) {
      case AlertPerimeterType.inside:
        return AppColors.sage;
      case AlertPerimeterType.outside:
        return AppColors.error;
      case AlertPerimeterType.approaching:
        return AppColors.warning;
      case AlertPerimeterType.timeDue:
        return AppColors.primary;
    }
  }

  String get _titleBadge {
    switch (widget.alertType) {
      case AlertPerimeterType.inside:
        return 'INSIDE PERIMETER';
      case AlertPerimeterType.outside:
        return 'LEFT PERIMETER';
      case AlertPerimeterType.approaching:
        return 'APPROACHING SPOT';
      case AlertPerimeterType.timeDue:
        return 'REMINDER DUE TIME';
    }
  }

  IconData get _statusIcon {
    switch (widget.alertType) {
      case AlertPerimeterType.inside:
        return Icons.verified_rounded;
      case AlertPerimeterType.outside:
        return Icons.warning_amber_rounded;
      case AlertPerimeterType.approaching:
        return Icons.near_me_rounded;
      case AlertPerimeterType.timeDue:
        return Icons.alarm_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Start concurrent real hardware vibration and MP3 tune playback
    AlarmAudioService.instance.startAlarm(
      loop: true,
      enableVibration: true,
      enableSound: true,
    );

    if (widget.alertType == AlertPerimeterType.timeDue) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _currentDateTime = DateTime.now();
          });
        }
      });
    }
  }

  void _silenceAlert() {
    if (_isSilenced) return;
    setState(() {
      _isSilenced = true;
    });
    AlarmAudioService.instance.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user presses power button or leaves screen, automatically silence
    if (state == AppLifecycleState.paused) {
      _silenceAlert();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _pulseController.dispose();
    AlarmAudioService.instance.stop();
    super.dispose();
  }

  String _formatDistanceTag(BuildContext context) {
    final liveLocation = context.watch<LiveLocationProvider>();
    final edgeDist = widget.edgeDistanceMeters ??
        liveLocation.calculateDistanceToPerimeterEdge(
          widget.reminder.latitude,
          widget.reminder.longitude,
          widget.reminder.radius,
        );

    final formatted = liveLocation.formatDistance(edgeDist);
    switch (widget.alertType) {
      case AlertPerimeterType.inside:
        return 'Inside perimeter! Spot trigger active.';
      case AlertPerimeterType.outside:
        return 'Outside perimeter ($formatted to perimeter edge)';
      case AlertPerimeterType.approaching:
        return 'Approaching spot ($formatted to perimeter)';
      case AlertPerimeterType.timeDue:
        return 'The scheduled due time has arrived!';
    }
  }

  Widget _buildTimeDueAlarmLayout(BuildContext context, Reminder r) {
    final timeStr = DateFormat('hh:mm').format(_currentDateTime);
    final amPmStr = DateFormat('a').format(_currentDateTime);
    final dateStr = DateFormat('EEEE, d MMMM').format(_currentDateTime);
    final categoryColor = AppColors.categoryColor(r.category.name);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E1B4B),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'SMARTSPOT ALARM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const Spacer(flex: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 84,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  amPmStr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(flex: 2),
            SizedBox(
              height: 180,
              width: 180,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.45),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(
                              alpha: _isSilenced
                                  ? 0.02
                                  : (0.18 * (1.0 - _pulseController.value)),
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.25),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(
                              alpha: _isSilenced
                                  ? 0.04
                                  : (0.28 * (1.0 - _pulseController.value)),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                  alpha: _isSilenced ? 0.25 : 0.55),
                              blurRadius: _isSilenced ? 12 : 28,
                              spreadRadius: _isSilenced ? 1 : 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isSilenced
                                ? Icons.notifications_paused_rounded
                                : Icons.alarm_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.categoryEmoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            r.category.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: categoryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (r.description != null && r.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        r.description!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (r.locationName != null && r.locationName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.place_rounded, size: 14, color: categoryColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              r.locationName!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: TextButton(
                  onPressed: () async {
                    _silenceAlert();
                    final snoozed = r.copyWith(
                      dueDate: DateTime.now().add(const Duration(minutes: 5)),
                    );
                    await context.read<ReminderProvider>().updateReminder(snoozed);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Alarm snoozed for 5 minutes'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                  ),
                  child: const Text(
                    'Snooze for 5 min',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    _silenceAlert();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    final r = widget.reminder;
    if (widget.alertType == AlertPerimeterType.timeDue) {
      return Scaffold(
        body: _buildTimeDueAlarmLayout(context, r),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = AppColors.categoryColor(r.category.name);
    final distanceTag = _formatDistanceTag(context);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0D14) : const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon, size: 14, color: _accentColor),
                        const SizedBox(width: 6),
                        Text(
                          _titleBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _accentColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Radar Wave Animation
                    SizedBox(
                      height: 220,
                      width: 220,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ripple 1
                              Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.45),
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _accentColor.withValues(
                                      alpha: _isSilenced
                                          ? 0.04
                                          : (0.22 *
                                              (1.0 - _pulseController.value)),
                                    ),
                                  ),
                                ),
                              ),
                              // Outer ripple 2
                              Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.25),
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _accentColor.withValues(
                                      alpha: _isSilenced
                                          ? 0.08
                                          : (0.35 *
                                              (1.0 - _pulseController.value)),
                                    ),
                                  ),
                                ),
                              ),
                              // Core glowing circle
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accentColor.withValues(
                                          alpha: _isSilenced ? 0.3 : 0.6),
                                      blurRadius: _isSilenced ? 16 : 32,
                                      spreadRadius: _isSilenced ? 2 : 6,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _isSilenced
                                        ? Icons.volume_off_rounded
                                        : Icons.vibration_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Vibration Status Pill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isSilenced
                            ? Colors.grey.withValues(alpha: 0.15)
                            : _accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSilenced
                                ? Icons.notifications_off_rounded
                                : Icons.graphic_eq_rounded,
                            size: 14,
                            color: _isSilenced ? Colors.grey : _accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSilenced
                                ? 'Vibration & Sound Silenced'
                                : 'Vibrating • vibration_sound.mp3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isSilenced ? Colors.grey : _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reminder Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.4 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(r.categoryEmoji,
                                        style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Text(
                                      r.category.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: categoryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Radius: ${r.radius.toInt()}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            r.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (r.description != null &&
                              r.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(Icons.place_rounded,
                                  size: 18, color: _accentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.locationName ??
                                      '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _accentColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: _accentColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    distanceTag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Hardware Power Button Notice Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF1E2433) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.power_settings_new_rounded,
                              size: 18, color: Colors.grey[400]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tip: Press phone Power button or Volume keys anytime to silence vibration',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Silence Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _silenceAlert,
                      icon: Icon(
                        _isSilenced
                            ? Icons.check_circle_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isSilenced
                            ? 'VIBRATION SILENCED'
                            : 'STOP VIBRATION & SOUND',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isSilenced ? Colors.grey[700] : _accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: _isSilenced ? 0 : 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // View Live Map
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _silenceAlert();
                            Navigator.push(
                              context,
                              AppPageRoute(
                                builder: (_) => LiveMapScreen(reminder: r),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Live Map'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Mark Completed
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            _silenceAlert();
                            await context
                                .read<ReminderProvider>()
                                .toggleCompletion(r.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Done'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
