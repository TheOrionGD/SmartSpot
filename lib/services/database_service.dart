import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder.dart';
import '../models/location_visit.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smartspot.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        locationName TEXT,
        radius REAL NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        isCompleted INTEGER NOT NULL,
        isArchived INTEGER NOT NULL,
        notifyOnEnter INTEGER NOT NULL,
        notifyOnExit INTEGER NOT NULL,
        routeAware INTEGER NOT NULL DEFAULT 0,
        weatherAware INTEGER NOT NULL DEFAULT 0,
        conditions TEXT NOT NULL DEFAULT '',
        missedCount INTEGER NOT NULL DEFAULT 0,
        dependsOn TEXT NOT NULL DEFAULT '',
        adaptiveRadius INTEGER NOT NULL DEFAULT 0,
        repeatType TEXT NOT NULL DEFAULT 'once',
        repeatDays TEXT NOT NULL DEFAULT '',
        lastCompletedAt TEXT
      )
    ''');
    await _createIntelligenceTables(db);
  }

  Future<void> _createIntelligenceTables(Database db) async {
    // Raw "you were here" samples — the fuel for the predictive engine,
    // location learning, and personalized insights.
    await db.execute('''
      CREATE TABLE location_visits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        locationName TEXT,
        category TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
    // One row per (reminder, calendar day) it was still pending when its
    // due window closed — feeds "Missed Reminder Prediction".
    await db.execute('''
      CREATE TABLE missed_events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminderId TEXT NOT NULL,
        missedAt TEXT NOT NULL
      )
    ''');
  }

  /// v1 -> v2: adds recurring-reminder support. Existing rows default to
  /// repeatType='once' (i.e. behave exactly as before the migration).
  /// v2 -> v3: persists routeAware/weatherAware (previously UI-only) and
  /// adds the columns/tables backing the intelligent-engine features
  /// (multi-condition rules, dependencies, adaptive radius, missed-reminder
  /// tracking, location learning).
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE reminders ADD COLUMN repeatType TEXT NOT NULL DEFAULT 'once'",
      );
      await db.execute(
        "ALTER TABLE reminders ADD COLUMN repeatDays TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE reminders ADD COLUMN lastCompletedAt TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE reminders ADD COLUMN routeAware INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE reminders ADD COLUMN weatherAware INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE reminders ADD COLUMN conditions TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE reminders ADD COLUMN missedCount INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE reminders ADD COLUMN dependsOn TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE reminders ADD COLUMN adaptiveRadius INTEGER NOT NULL DEFAULT 0',
      );
      await _createIntelligenceTables(db);
    }
  }

  /// Resets recurring reminders that were completed on a previous
  /// occurrence back to pending, so they're ready to trigger again today.
  /// A reminder only qualifies if it repeats, is currently marked
  /// complete, is due today per its schedule, and wasn't already
  /// completed earlier today. Safe to call often (e.g. on every app
  /// launch / reminder list refresh) — it's a no-op when nothing qualifies.
  Future<void> resetDueRecurringReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'isCompleted = ? AND isArchived = ? AND repeatType != ?',
      whereArgs: [1, 0, 'once'],
    );

    final today = DateTime.now();
    for (final map in maps) {
      final reminder = Reminder.fromMap(map);
      if (reminder.shouldResetFor(today)) {
        await db.update(
          'reminders',
          {'isCompleted': 0},
          where: 'id = ?',
          whereArgs: [reminder.id],
        );
      }
    }
  }

  Future<String> createReminder(Reminder reminder) async {
    final db = await database;
    final id = const Uuid().v4();
    final reminderWithId = reminder.copyWith(id: id);

    await db.insert(
      'reminders',
      reminderWithId.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<List<Reminder>> getActiveReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'isCompleted = ? AND isArchived = ?',
      whereArgs: [0, 0],
      orderBy: 'priority DESC, createdAt DESC',
    );

    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<List<Reminder>> getRemindersByCategory(ReminderCategory category) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'category = ? AND isArchived = ?',
      whereArgs: [category.toString().split('.').last, 0],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<List<Reminder>> getCompletedReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'isCompleted = ? AND isArchived = ?',
      whereArgs: [1, 0],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<List<Reminder>> getArchivedReminders() async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'isArchived = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<Reminder?> getReminderById(String id) async {
    final db = await database;
    final maps = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> toggleCompletion(String id) async {
    final reminder = await getReminderById(id);
    if (reminder != null) {
      final nowCompleted = !reminder.isCompleted;
      await updateReminder(
        reminder.copyWith(
          isCompleted: nowCompleted,
          // Stamp completion time so recurring reminders know whether
          // they were already completed "today" vs. a previous occurrence.
          // Left unchanged when un-completing — resetDueRecurringReminders
          // only reads this field for rows where isCompleted = 1.
          lastCompletedAt: nowCompleted ? DateTime.now() : reminder.lastCompletedAt,
        ),
      );
    }
  }

  Future<void> archiveReminder(String id) async {
    final reminder = await getReminderById(id);
    if (reminder != null) {
      await updateReminder(reminder.copyWith(isArchived: true));
    }
  }

  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE isArchived = 0',
    );
    final total = totalResult.isNotEmpty
        ? (totalResult.first['count'] as int?) ?? 0
        : 0;

    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE isCompleted = 1 AND isArchived = 0',
    );
    final completed = completedResult.isNotEmpty
        ? (completedResult.first['count'] as int?) ?? 0
        : 0;

    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reminders WHERE isCompleted = 0 AND isArchived = 0',
    );
    final pending = pendingResult.isNotEmpty
        ? (pendingResult.first['count'] as int?) ?? 0
        : 0;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }

  Future<List<Reminder>> getRemindersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.query(
      'reminders',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return List.generate(maps.length, (i) => Reminder.fromMap(maps[i]));
  }

  Future<void> incrementMissedCount(String id) async {
    final reminder = await getReminderById(id);
    if (reminder == null) return;
    await updateReminder(reminder.copyWith(missedCount: reminder.missedCount + 1));
    final db = await database;
    await db.insert('missed_events', {
      'reminderId': id,
      'missedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> resetMissedCount(String id) async {
    final reminder = await getReminderById(id);
    if (reminder == null) return;
    await updateReminder(reminder.copyWith(missedCount: 0));
  }

  // --- Location learning / predictive engine -----------------------------

  Future<void> recordVisit(LocationVisit visit) async {
    final db = await database;
    await db.insert('location_visits', visit.toMap());
  }

  /// Visits from the last [days] days, most recent first. Used to detect
  /// recurring patterns ("you're usually here Saturdays around 5 PM").
  Future<List<LocationVisit>> getRecentVisits({int days = 90}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final maps = await db.query(
      'location_visits',
      where: 'timestamp >= ?',
      whereArgs: [cutoff],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => LocationVisit.fromMap(maps[i]));
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}