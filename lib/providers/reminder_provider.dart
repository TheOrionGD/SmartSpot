import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/database_service.dart';
import '../services/intelligence_service.dart';
import '../services/api_service.dart';

class ReminderProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final IntelligenceService _intelligence = IntelligenceService.instance;
  final ApiService _apiService = ApiService.instance;

  final Set<String> _missedCheckedThisSession = {};

  List<Reminder> _allReminders = [];
  List<Reminder> _filteredReminders = [];
  List<Reminder> _archivedReminders = [];
  List<Reminder> _completedReminders = [];
  ReminderCategory? _selectedCategory;
  Map<String, int> _statistics = {'total': 0, 'completed': 0, 'pending': 0};
  bool _isLoading = false;

  List<Reminder> get allReminders => _allReminders;
  List<Reminder> get filteredReminders => _filteredReminders;
  List<Reminder> get archivedReminders => _archivedReminders;
  List<Reminder> get completedReminders => _completedReminders;
  ReminderCategory? get selectedCategory => _selectedCategory;
  Map<String, int> get statistics => _statistics;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadReminders();
      await loadStatistics();
      await _checkForMissedReminders();
      await syncWithBackend();
    } catch (e) {
      debugPrint('Error initializing ReminderProvider: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncWithBackend() async {
    try {
      final allLocal = await _dbService.getAllReminders();
      final remoteReminders = await _apiService.syncReminders(allLocal);

      for (final remote in remoteReminders) {
        await _dbService.updateReminder(remote);
      }

      await loadReminders();
      await loadStatistics();
    } catch (e) {
      debugPrint('Backend sync skipped or offline: $e');
    }
  }

  // --- Feature 16 — Missed Reminder Prediction ------------------------
  Future<void> _checkForMissedReminders() async {
    final now = DateTime.now();
    for (final reminder in _allReminders) {
      if (reminder.isCompleted || reminder.dueDate == null) continue;
      if (_missedCheckedThisSession.contains(reminder.id)) continue;
      if (now.difference(reminder.dueDate!) > const Duration(hours: 1)) {
        _missedCheckedThisSession.add(reminder.id);
        await _dbService.incrementMissedCount(reminder.id);
      }
    }
  }

  // --- Intelligence engine passthroughs --------------------------------
  Future<List<SmartSuggestion>> getSmartSuggestions() {
    return _intelligence.generatePredictiveSuggestions(existingReminders: _allReminders);
  }

  Future<List<Insight>> getInsights() {
    return _intelligence.generateInsights([..._allReminders, ..._archivedReminders]);
  }

  Future<List<MissedReminderSuggestion>> getMissedReminderSuggestions() {
    return _intelligence.getMissedReminderSuggestions(_allReminders);
  }

  ReminderPriority suggestPriority(String title, {String? description, DateTime? dueDate}) {
    return _intelligence.suggestPriority(title, description: description, dueDate: dueDate);
  }

  List<Reminder> get relevanceRankedReminders => _intelligence.rankByRelevance(_filteredReminders);

  bool dependenciesSatisfied(Reminder reminder) =>
      _intelligence.dependenciesSatisfied(reminder, _allReminders);

  Future<void> applyMissedSuggestion(MissedReminderSuggestion suggestion) async {
    final updated = suggestion.reminder.copyWith(
      dueDate: suggestion.suggestedDateTime,
      missedCount: 0,
    );
    await updateReminder(updated);
    _missedCheckedThisSession.remove(updated.id);
  }

  Future<void> loadReminders() async {
    try {
      await _dbService.resetDueRecurringReminders();
      _allReminders = await _dbService.getActiveReminders();
      _filteredReminders = _selectedCategory == null
          ? _allReminders
          : _allReminders.where((r) => r.category == _selectedCategory).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reminders: $e');
    }
  }

  Future<void> loadStatistics() async {
    try {
      _statistics = await _dbService.getStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> loadArchived() async {
    try {
      _archivedReminders = await _dbService.getArchivedReminders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading archived reminders: $e');
    }
  }

  Future<void> loadCompleted() async {
    try {
      _completedReminders = await _dbService.getCompletedReminders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading completed reminders: $e');
    }
  }

  Future<void> restoreReminder(String id) async {
    try {
      final reminder = await _dbService.getReminderById(id);
      if (reminder != null) {
        final restored = reminder.copyWith(isArchived: false);
        await _dbService.updateReminder(restored);
        try {
          await _apiService.toggleArchive(id, isArchived: false);
        } catch (_) {}
        await loadArchived();
        await loadReminders();
        await loadStatistics();
      }
    } catch (e) {
      debugPrint('Error restoring reminder: $e');
      rethrow;
    }
  }

  void filterByCategory(ReminderCategory? category) {
    _selectedCategory = category;
    if (category == null) {
      _filteredReminders = _allReminders;
    } else {
      _filteredReminders = _allReminders
          .where((reminder) => reminder.category == category)
          .toList();
    }
    notifyListeners();
  }

  Future<String> addReminder(Reminder reminder) async {
    try {
      final id = await _dbService.createReminder(reminder);
      final created = reminder.copyWith(id: id);
      try {
        await _apiService.createReminder(created);
      } catch (e) {
        debugPrint('Backend sync on create failed: $e');
      }
      await loadReminders();
      await loadStatistics();
      return id;
    } catch (e) {
      debugPrint('Error adding reminder: $e');
      rethrow;
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    try {
      await _dbService.updateReminder(reminder);
      try {
        await _apiService.updateReminder(reminder);
      } catch (e) {
        debugPrint('Backend sync on update failed: $e');
      }
      await loadReminders();
      await loadStatistics();
    } catch (e) {
      debugPrint('Error updating reminder: $e');
      rethrow;
    }
  }

  Future<void> toggleCompletion(String id) async {
    try {
      await _dbService.toggleCompletion(id);
      final updated = await _dbService.getReminderById(id);
      if (updated != null) {
        try {
          await _apiService.toggleComplete(id, isCompleted: updated.isCompleted);
        } catch (_) {}
      }
      await loadReminders();
      await loadStatistics();
      await loadCompleted();
    } catch (e) {
      debugPrint('Error toggling completion: $e');
      rethrow;
    }
  }

  Future<void> archiveReminder(String id) async {
    try {
      await _dbService.archiveReminder(id);
      try {
        await _apiService.toggleArchive(id, isArchived: true);
      } catch (_) {}
      await loadReminders();
      await loadStatistics();
      await loadArchived();
    } catch (e) {
      debugPrint('Error archiving reminder: $e');
      rethrow;
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _dbService.deleteReminder(id);
      try {
        await _apiService.deleteReminder(id);
      } catch (_) {}
      await loadReminders();
      await loadStatistics();
      await loadArchived();
      await loadCompleted();
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      rethrow;
    }
  }

  void searchReminders(String query) {
    if (query.isEmpty) {
      _filteredReminders = _allReminders;
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredReminders = _allReminders
          .where((reminder) =>
              reminder.title.toLowerCase().contains(lowerQuery) ||
              (reminder.description?.toLowerCase().contains(lowerQuery) ?? false) ||
              (reminder.locationName?.toLowerCase().contains(lowerQuery) ?? false))
          .toList();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _dbService.close();
    super.dispose();
  }
}