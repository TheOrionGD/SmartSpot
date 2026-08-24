import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_theme.dart';

/// Centralized motion system and animation utilities for SmartSpot.
/// Enforces consistent timing, physically-believable easing curves,
/// accessibility compliance (Reduced Motion), and signature micro-animations.
class AppMotion {
  AppMotion._();

  // --- Duration Scale --------------------------------------------------------
  static const Duration micro = Duration(milliseconds: 140);
  static const Duration component = Duration(milliseconds: 220);
  static const Duration screen = Duration(milliseconds: 300);
  static const Duration data = Duration(milliseconds: 650);
  static const Duration ambient = Duration(milliseconds: 2800);

  // --- Curves ----------------------------------------------------------------
  static const Curve easeOutFast = Curves.easeOutQuad;
  static const Curve easeOutSmooth = Curves.easeOutCubic;
  static const Curve screenCurve = Curves.fastOutSlowIn;
  static const Curve springCurve = Cubic(0.175, 0.885, 0.32, 1.15); // subtle overshoot spring
  static const Curve chartCurve = Curves.easeOutQuart;

  /// Checks if motion should be animated according to system accessibility settings
  /// or user-configured Reduced Motion preference.
  static bool shouldAnimate(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return false;
    try {
      final settings = context.read<SettingsProvider>();
      return !settings.reducedMotion;
    } catch (_) {
      return true;
    }
  }

  /// Utility for staggered animations delay calculation
  static Duration staggerDuration(int index, {int stepMs = 50, int baseMs = 0}) {
    return Duration(milliseconds: baseMs + (index * stepMs));
  }
}

/// Custom PageRoute that provides SmartSpot's signature entrance/exit transition.
/// Enter: Opacity 0 -> 1, Translate Y 10px -> 0
/// Exit: Opacity 1 -> 0, Translate Y 0 -> -6px
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder? builder;
  final Widget? child;

  AppPageRoute({this.builder, this.child, super.settings})
      : assert(builder != null || child != null),
        super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder != null ? builder(context) : child!,
          transitionDuration: AppMotion.screen,
          reverseTransitionDuration: AppMotion.component,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (!AppMotion.shouldAnimate(context)) {
              return child;
            }

            final primaryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );
            final primarySlide = Tween<Offset>(
              begin: const Offset(0.0, 0.04), // ~10px equivalent
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: AppMotion.screenCurve),
            );

            final secondaryFade = Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
            );
            final secondarySlide = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(0.0, -0.02), // ~-6px equivalent
            ).animate(
              CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
            );

            return FadeTransition(
              opacity: primaryFade,
              child: SlideTransition(
                position: primarySlide,
                child: FadeTransition(
                  opacity: secondaryFade,
                  child: SlideTransition(
                    position: secondarySlide,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// Custom Painter that physically draws a checkmark vector path (0.0 -> 1.0 progress).
class AnimatedCheckmark extends StatelessWidget {
  final double progress;
  final Color color;
  final double strokeWidth;

  const AnimatedCheckmark({
    super.key,
    required this.progress,
    this.color = Colors.white,
    this.strokeWidth = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _CheckmarkPainter(
        progress: progress,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final p1 = Offset(size.width * 0.22, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.74);
    final p3 = Offset(size.width * 0.80, size.height * 0.30);

    final leg1Length = (p2 - p1).distance;
    final leg2Length = (p3 - p2).distance;
    final totalLength = leg1Length + leg2Length;

    final currentLength = totalLength * progress.clamp(0.0, 1.0);

    path.moveTo(p1.dx, p1.dy);

    if (currentLength <= leg1Length) {
      final t = currentLength / leg1Length;
      final currentPt = Offset.lerp(p1, p2, t)!;
      path.lineTo(currentPt.dx, currentPt.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (currentLength - leg1Length) / leg2Length;
      final currentPt = Offset.lerp(p2, p3, t)!;
      path.lineTo(currentPt.dx, currentPt.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Celebratory micro-particle spark burst that radiates around the checkbox button
/// when completing a reminder.
class CompletionRewardBurstWidget extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onComplete;

  const CompletionRewardBurstWidget({
    super.key,
    required this.child,
    required this.trigger,
    this.onComplete,
  });

  @override
  State<CompletionRewardBurstWidget> createState() => _CompletionRewardBurstWidgetState();
}

class _CompletionRewardBurstWidgetState extends State<CompletionRewardBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });

    if (widget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(CompletionRewardBurstWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.value == 0 || _controller.value == 1) {
              return const SizedBox.shrink();
            }
            return CustomPaint(
              size: const Size(60, 60),
              painter: _RewardBurstPainter(progress: _controller.value),
            );
          },
        ),
      ],
    );
  }
}

class _RewardBurstPainter extends CustomPainter {
  final double progress;

  _RewardBurstPainter({required this.progress});

  static const _particleColors = [
    AppColors.primary,
    AppColors.sage,
    AppColors.primaryLight,
    AppColors.periwinkle,
    Color(0xFFFFB020),
    Color(0xFFE8639B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.75;
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    const count = 8;
    for (int i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + (progress * 0.3);
      final px = center.dx + math.cos(angle) * radius;
      final py = center.dy + math.sin(angle) * radius;

      final color = _particleColors[i % _particleColors.length].withValues(alpha: opacity);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final dotRadius = (3.2 * (1.0 - progress)).clamp(1.0, 3.2);
      canvas.drawCircle(Offset(px, py), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_RewardBurstPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Smooth numeric counter animation for values, percentages, or distances.
class AnimatedCounterText extends StatelessWidget {
  final double value;
  final String Function(double val) formatter;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounterText({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = AppMotion.data,
  });

  @override
  Widget build(BuildContext context) {
    final animate = AppMotion.shouldAnimate(context);
    if (!animate) {
      return Text(formatter(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: AppMotion.chartCurve,
      builder: (context, val, child) {
        return Text(formatter(val), style: style);
      },
    );
  }
}

/// Dark-indigo shimmer loading placeholder widget for skeleton loading states.
class AppSkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<AppSkeletonShimmer> createState() => _AppSkeletonShimmerState();
}

class _AppSkeletonShimmerState extends State<AppSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.surfaceDark : Colors.grey[300]!;
    final highlightColor = isDark
        ? AppColors.primary.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2.0), -0.3),
              end: Alignment(1.0 + (_controller.value * 2.0), 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal shake animation container for invalid field inputs.
/// Moves -3px -> +3px -> 0 in ~200ms.
class ErrorShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  final VoidCallback? onShakeComplete;

  const ErrorShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.onShakeComplete,
  });

  @override
  State<ErrorShakeWidget> createState() => _ErrorShakeWidgetState();
}

class _ErrorShakeWidgetState extends State<ErrorShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onShakeComplete?.call();
        }
      });

    if (widget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(ErrorShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = math.sin(_controller.value * math.pi * 3) * 3.5;
        return Transform.translate(
          offset: Offset(val, 0),
          child: widget.child,
        );
      },
    );
  }
}
