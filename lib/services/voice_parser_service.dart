import '../models/reminder.dart';

/// Result of parsing a free-form sentence like "remind me to buy milk when
/// I reach Reliance tomorrow evening" into structured reminder fields.
/// Any field the parser couldn't confidently extract is left null so the
/// UI can fall back to its normal defaults / ask the user to fill it in.
class ParsedReminder {
  final String title;
  final String? locationHint;
  final DateTime? dueDate;
  final ReminderCategory? category;
  final String rawText;

  const ParsedReminder({
    required this.title,
    this.locationHint,
    this.dueDate,
    this.category,
    required this.rawText,
  });
}

/// Feature 6 — Natural-Language Voice Reminders.
///
/// This is a lightweight, fully offline rule-based parser (regex +
/// keyword matching) — no cloud NLP API required, so it works without any
/// API key and with zero network latency. It's intentionally conservative:
/// it only fills in a field when it finds a reasonably unambiguous signal,
/// leaving everything else for the user to confirm on the review screen.
///
/// Pair this with any speech-to-text front end (e.g. the `speech_to_text`
/// package) — this class only deals with the resulting transcript string,
/// it doesn't touch the microphone itself.
class VoiceParserService {
  VoiceParserService._();

  static final RegExp _leadIn = RegExp(
    r'^\s*(remind me to|remind me|please remind me to|set a reminder to|set reminder to)\s*',
    caseSensitive: false,
  );

  static final RegExp _locationClause = RegExp(
    r'\b(when i (?:reach|get to|arrive at|am at|am near)|at|near)\s+([a-zA-Z0-9\s]+?)(?=\s+(?:tomorrow|today|tonight|this|next|on|at\s+\d|morning|afternoon|evening|night|$)|[.,]|$)',
    caseSensitive: false,
  );

  static final Map<String, ReminderCategory> _categoryKeywords = {
    'buy': ReminderCategory.shopping,
    'shop': ReminderCategory.shopping,
    'grocery': ReminderCategory.shopping,
    'groceries': ReminderCategory.shopping,
    'milk': ReminderCategory.shopping,
    'medicine': ReminderCategory.health,
    'tablet': ReminderCategory.health,
    'doctor': ReminderCategory.health,
    'gym': ReminderCategory.health,
    'exercise': ReminderCategory.health,
    'class': ReminderCategory.college,
    'assignment': ReminderCategory.college,
    'submit': ReminderCategory.college,
    'exam': ReminderCategory.college,
    'college': ReminderCategory.college,
    'meeting': ReminderCategory.office,
    'report': ReminderCategory.office,
    'office': ReminderCategory.office,
    'client': ReminderCategory.office,
    'flight': ReminderCategory.travel,
    'train': ReminderCategory.travel,
    'ticket': ReminderCategory.travel,
    'pack': ReminderCategory.travel,
    'clean': ReminderCategory.home,
    'laundry': ReminderCategory.home,
    'bill': ReminderCategory.home,
    'rent': ReminderCategory.home,
  };

  static ParsedReminder parse(String input) {
    final raw = input.trim();
    var working = raw.replaceFirst(_leadIn, '').trim();

    String? locationHint;
    final locMatch = _locationClause.firstMatch(working);
    if (locMatch != null) {
      locationHint = locMatch.group(2)?.trim();
      working = working.replaceRange(locMatch.start, locMatch.end, '').trim();
    }

    final dueDate = _extractDate(working);
    // Strip the date/time words we matched so they don't pollute the title.
    working = _stripDateWords(working).trim();
    working = working.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    // Tidy trailing conjunctions left over from clause removal.
    working = working.replaceAll(RegExp(r'\s+(and|when|at)\s*$', caseSensitive: false), '').trim();

    final category = _guessCategory(raw);
    final title = working.isEmpty ? raw : _capitalize(working);

    return ParsedReminder(
      title: title,
      locationHint: (locationHint != null && locationHint.isNotEmpty) ? locationHint : null,
      dueDate: dueDate,
      category: category,
      rawText: raw,
    );
  }

  static DateTime? _extractDate(String text) {
    final lower = text.toLowerCase();
    final now = DateTime.now();
    DateTime base = now;

    if (lower.contains('tomorrow')) {
      base = now.add(const Duration(days: 1));
    } else if (lower.contains('tonight')) {
      base = now;
    } else if (lower.contains('next week')) {
      base = now.add(const Duration(days: 7));
    } else {
      const days = [
        'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
      ];
      for (var i = 0; i < days.length; i++) {
        if (lower.contains(days[i])) {
          final targetWeekday = i + 1;
          var delta = targetWeekday - now.weekday;
          if (delta <= 0) delta += 7;
          base = now.add(Duration(days: delta));
          break;
        }
      }
    }

    int hour = 9; // sensible default
    if (lower.contains('morning')) {
      hour = 9;
    } else if (lower.contains('afternoon')) {
      hour = 14;
    } else if (lower.contains('evening')) {
      hour = 18;
    } else if (lower.contains('night') || lower.contains('tonight')) {
      hour = 20;
    }

    final explicitTime = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', caseSensitive: false)
        .firstMatch(lower);
    int minute = 0;
    if (explicitTime != null) {
      var h = int.parse(explicitTime.group(1)!);
      minute = int.tryParse(explicitTime.group(2) ?? '0') ?? 0;
      final period = explicitTime.group(3)!.toLowerCase();
      if (period == 'pm' && h != 12) h += 12;
      if (period == 'am' && h == 12) h = 0;
      hour = h;
    }

    final hasAnySignal = lower.contains('tomorrow') ||
        lower.contains('tonight') ||
        lower.contains('next week') ||
        explicitTime != null ||
        lower.contains('morning') ||
        lower.contains('afternoon') ||
        lower.contains('evening') ||
        lower.contains('night');
    if (!hasAnySignal) return null;

    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  static String _stripDateWords(String text) {
    return text.replaceAll(
      RegExp(
        r'\b(tomorrow|tonight|next week|morning|afternoon|evening|night|'
        r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
        r'\d{1,2}(?::\d{2})?\s*(?:am|pm))\b',
        caseSensitive: false,
      ),
      '',
    );
  }

  static ReminderCategory? _guessCategory(String text) {
    final lower = text.toLowerCase();
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
