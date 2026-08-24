import 'package:flutter/material.dart';
import '../services/voice_parser_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_translations.dart';

/// Feature 6 — Natural-Language Voice Reminders.
///
/// Takes typed or transcribed free-form text and parses it into structured
/// reminder fields via [VoiceParserService].
class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();

  /// Shows the sheet and returns the parsed result, or null if cancelled.
  static Future<ParsedReminder?> show(BuildContext context) {
    return showModalBottomSheet<ParsedReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceInputSheet(),
    );
  }
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final _controller = TextEditingController();
  ParsedReminder? _preview;

  void _updatePreview(String text) {
    setState(() => _preview = text.trim().isEmpty ? null : VoiceParserService.parse(text));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AppTranslations.tr(context, 'voice_quick_add'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type (or speak) something like "remind me to buy milk when I reach Reliance tomorrow evening".',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            onChanged: _updatePreview,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: AppTranslations.tr(context, 'remind_me_to'),
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            ),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _previewRow(Icons.title_rounded, 'Title', _preview!.title),
                  if (_preview!.locationHint != null)
                    _previewRow(Icons.place_rounded, 'Near', _preview!.locationHint!),
                  if (_preview!.dueDate != null)
                    _previewRow(Icons.event_rounded, 'When',
                        '${_preview!.dueDate!.day}/${_preview!.dueDate!.month} at ${_preview!.dueDate!.hour.toString().padLeft(2, '0')}:${_preview!.dueDate!.minute.toString().padLeft(2, '0')}'),
                  if (_preview!.category != null)
                    _previewRow(Icons.category_rounded, 'Category', _preview!.category!.name),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _preview == null ? null : AppColors.primaryGradient,
                color: _preview == null ? (isDark ? Colors.grey[800] : Colors.grey[300]) : null,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _preview == null
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _preview == null ? null : () => Navigator.pop(context, _preview),
                  child: Center(
                    child: Text(
                      AppTranslations.tr(context, 'use_this'),
                      style: TextStyle(
                        color: _preview == null
                            ? (isDark ? Colors.grey[500] : Colors.grey[600])
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  Widget _previewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
