import 'package:flutter/material.dart';
import '../services/voice_parser_service.dart';
import '../utils/app_theme.dart';

/// Feature 6 — Natural-Language Voice Reminders.
///
/// This sheet takes typed (or, once a speech-to-text package is wired in,
/// transcribed) free-form text like "remind me to buy milk when I reach
/// Reliance tomorrow evening" and parses it into structured fields via
/// [VoiceParserService].
///
/// Deliberately decoupled from any specific speech-to-text plugin: hook a
/// mic button up to `speech_to_text` (or any STT source) and feed its
/// transcript into [controller.text] — everything below only cares about
/// the resulting string, not how it got there.
class VoiceInputSheet extends StatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();

  /// Shows the sheet and returns the parsed result, or null if cancelled.
  static Future<ParsedReminder?> show(BuildContext context) {
    return showModalBottomSheet<ParsedReminder>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Voice / Quick Add', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type (or speak, if your app has mic input wired up) something like '
            '"remind me to buy milk when I reach Reliance tomorrow evening".',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            onChanged: _updatePreview,
            decoration: const InputDecoration(
              hintText: 'Remind me to…',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
            ),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _preview == null ? null : AppColors.primaryGradient,
                color: _preview == null ? Colors.grey[300] : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _preview == null ? null : () => Navigator.pop(context, _preview),
                  child: const Center(
                    child: Text(
                      'Use this',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
