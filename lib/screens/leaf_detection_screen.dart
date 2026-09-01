import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/leaf_detection_service.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';

/// States the leaf detection screen can be in.
enum _DetectState { idle, loading, success, rejected, error }

/// A full-screen premium Leaf / Plant Detection screen.
///
/// The user can take a photo or pick from gallery. The image is sent to the
/// SmartSpot backend which uses Gemini Vision AI to determine whether the
/// capture is a plant / leaf / seedling.
///
/// - ✅  Plant detected  → green result card showing label + confidence
/// - ❌  Not a plant     → red rejection card with reason + retry button
/// - ⚠️  Error           → error card with retry button
class LeafDetectionScreen extends StatefulWidget {
  const LeafDetectionScreen({super.key});

  @override
  State<LeafDetectionScreen> createState() => _LeafDetectionScreenState();
}

class _LeafDetectionScreenState extends State<LeafDetectionScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  _DetectState _state = _DetectState.idle;
  Uint8List? _imageBytes;
  String? _imageMime;
  LeafDetectionResult? _result;
  String? _errorMessage;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Design constants – matching the app's "fintech" colour language
  static const _plantGreen = Color(0xFF00D9A3); // AppColors.sage
  static const _plantGreenDark = Color(0xFF00A87E);
  static const _rejectRed = Color(0xFFFF5A66); // AppColors.error

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      setState(() {
        _imageBytes = bytes;
        _imageMime = mime;
        _state = _DetectState.idle;
        _result = null;
        _errorMessage = null;
      });

      // Automatically analyse once an image is chosen
      await _analyse();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DetectState.error;
        _errorMessage = 'Could not open image: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Analysis
  // ---------------------------------------------------------------------------

  Future<void> _analyse() async {
    if (_imageBytes == null) return;
    setState(() {
      _state = _DetectState.loading;
      _result = null;
      _errorMessage = null;
    });

    try {
      final result = await LeafDetectionService.instance.analyzeImage(
        _imageBytes!,
        mimeType: _imageMime ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = result.isPlant ? _DetectState.success : _DetectState.rejected;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DetectState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DetectState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _reset() {
    setState(() {
      _state = _DetectState.idle;
      _imageBytes = null;
      _imageMime = null;
      _result = null;
      _errorMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? AppColors.creamBackgroundDark : AppColors.creamBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- Hero header ---------------------------------------------------
          SliverToBoxAdapter(
            child: _buildHeroHeader(isDark, topPad),
          ),

          // --- Content -------------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Image preview / placeholder
                  _buildImagePreview(isDark, animate),

                  const SizedBox(height: 24),

                  // Capture buttons
                  if (_state != _DetectState.loading)
                    _buildCaptureButtons(context, animate),

                  const SizedBox(height: 24),

                  // Result card
                  AnimatedSwitcher(
                    duration: animate ? AppMotion.component : Duration.zero,
                    switchInCurve: AppMotion.screenCurve,
                    child: _buildResultArea(isDark, animate),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Hero header ----------------------------------------------------------

  Widget _buildHeroHeader(bool isDark, double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_plantGreenDark, _plantGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaf Detection',
                  style: AppTypography.display(
                    fontSize: 22,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powered by Gemini Vision AI',
                  style: AppTypography.body(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Leaf icon badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  // --- Image preview --------------------------------------------------------

  Widget _buildImagePreview(bool isDark, bool animate) {
    const double size = 280;

    if (_imageBytes != null) {
      return Hero(
        tag: 'leaf_image_preview',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Image.memory(
                _imageBytes!,
                width: double.infinity,
                height: size,
                fit: BoxFit.cover,
              ),
              // Scanning overlay while loading
              if (_state == _DetectState.loading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _plantGreen.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _plantGreen.withValues(alpha: 0.55),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.eco_rounded,
                                color: _plantGreen, size: 36),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Analysing…',
                          style: AppTypography.body(
                            fontSize: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Placeholder
    return Container(
      width: double.infinity,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? _plantGreen.withValues(alpha: 0.08)
            : _plantGreen.withValues(alpha: 0.06),
        border: Border.all(
          color: _plantGreen.withValues(alpha: 0.28),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _plantGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 52,
              color: _plantGreen.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No image selected',
            style: AppTypography.display(
              fontSize: 16,
              weight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Capture or select a plant / leaf photo below',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // --- Capture buttons -------------------------------------------------------

  Widget _buildCaptureButtons(BuildContext context, bool animate) {
    return Row(
      children: [
        Expanded(
          child: _CaptureButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            animate: animate,
            gradient: const LinearGradient(
              colors: [_plantGreenDark, _plantGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _CaptureButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            animate: animate,
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  // --- Result area ----------------------------------------------------------

  Widget _buildResultArea(bool isDark, bool animate) {
    switch (_state) {
      case _DetectState.idle:
        return const SizedBox.shrink();

      case _DetectState.loading:
        return const SizedBox.shrink();

      case _DetectState.success:
        return _PlantResultCard(
          isDark: isDark,
          result: _result!,
          onReset: _reset,
          isSuccess: true,
        );

      case _DetectState.rejected:
        return _PlantResultCard(
          isDark: isDark,
          result: _result!,
          onReset: _reset,
          isSuccess: false,
        );

      case _DetectState.error:
        return _ErrorCard(
          isDark: isDark,
          message: _errorMessage ?? 'An unknown error occurred.',
          onRetry: _imageBytes != null ? _analyse : null,
          onReset: _reset,
        );
    }
  }
}

// =============================================================================
// Capture button widget
// =============================================================================

class _CaptureButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool animate;

  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    required this.animate,
  });

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: widget.animate ? AppMotion.micro : Duration.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: AppTypography.body(
                  fontSize: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Plant result card (success + rejected)
// =============================================================================

class _PlantResultCard extends StatelessWidget {
  final bool isDark;
  final LeafDetectionResult result;
  final VoidCallback onReset;
  final bool isSuccess;

  const _PlantResultCard({
    required this.isDark,
    required this.result,
    required this.onReset,
    required this.isSuccess,
  });

  static const _plantGreen = Color(0xFF00D9A3);
  static const _plantGreenDark = Color(0xFF00A87E);
  static const _rejectRed = Color(0xFFFF5A66);

  @override
  Widget build(BuildContext context) {
    final accent = isSuccess ? _plantGreen : _rejectRed;
    final accentDark = isSuccess ? _plantGreenDark : const Color(0xFFCC2233);
    final bgAlpha = isDark ? 0.12 : 0.07;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentDark, accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.eco_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? 'Plant Detected ✓' : 'Not a Plant ✗',
                      style: AppTypography.display(
                        fontSize: 16,
                        weight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    Text(
                      result.label,
                      style: AppTypography.body(
                        fontSize: 13,
                        weight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF1A2035),
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${result.confidence}%',
                  style: AppTypography.body(
                    fontSize: 14,
                    weight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),

          if (result.reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.reason,
                style: AppTypography.body(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.grey[700],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Confidence progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confidence',
                    style: AppTypography.body(
                      fontSize: 11,
                      weight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${result.confidence}%',
                    style: AppTypography.body(
                      fontSize: 11,
                      weight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: result.confidence / 100.0,
                  minHeight: 7,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Scan again button
          GestureDetector(
            onTap: onReset,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentDark, accent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Scan Another Image',
                    style: AppTypography.body(
                      fontSize: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Error card
// =============================================================================

class _ErrorCard extends StatelessWidget {
  final bool isDark;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onReset;

  const _ErrorCard({
    required this.isDark,
    required this.message,
    this.onRetry,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: accent, size: 36),
          const SizedBox(height: 10),
          Text(
            'Something went wrong',
            style: AppTypography.display(
              fontSize: 15,
              weight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (onRetry != null) ...[
                Expanded(
                  child: _actionButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    color: accent,
                    onTap: onRetry!,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _actionButton(
                  label: 'New Image',
                  icon: Icons.camera_alt_rounded,
                  color: AppColors.primary,
                  onTap: onReset,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.body(
                fontSize: 13,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
