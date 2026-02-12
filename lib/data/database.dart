import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// Task categories for organizing tasks
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()(); // Stored as hex int (e.g., 0xFF4CAF50)
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Main tasks table
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2196F3))();
  TextColumn get priority =>
      text().withDefault(const Constant('Medium'))(); // Low, Medium, High
  DateTimeColumn get dueDate => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get timeSpentSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isRepeating => boolean().withDefault(const Constant(false))();
  DateTimeColumn get repeatEndDate => dateTime().nullable()();
  TextColumn get repeatId => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get isReminding => boolean().withDefault(const Constant(false))();
}

/// Pomodoro session records for time tracking
class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id)();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// Events for calendar integration
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2196F3))();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get durationMinutes => integer()();
  BoolColumn get isRepeating => boolean().withDefault(const Constant(false))();
  DateTimeColumn get repeatEndDate => dateTime().nullable()();
  TextColumn get repeatId => text().nullable()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  BoolColumn get isReminding => boolean().withDefault(const Constant(false))();
}

/// App settings (single row table)
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get pomodoroMinutes => integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  BoolColumn get hasSeenIntro => boolean().withDefault(const Constant(false))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Categories, Tasks, PomodoroSessions, Events, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          // We added the repeatId column in v3
          await m.addColumn(tasks, tasks.repeatId);
        }
        if (from < 4) {
          try {
            await m.addColumn(appSettings, appSettings.themeMode);
          } catch (e) {
            print('Error adding themeMode column (likely already exists): $e');
          }
          try {
            await m.createTable(events);
          } catch (e) {
            print('Events table creation error (ignored): $e');
          }
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await customStatement(
          'UPDATE tasks SET due_date = ? WHERE due_date IS NULL',
          [now],
        );
        await customStatement(
          'UPDATE tasks SET title = \'Untitled\' WHERE title IS NULL',
        );
      },
    );
  }

  // ============ CATEGORIES ============
  Future<List<Category>> getAllCategories() => select(categories).get();
  Stream<List<Category>> watchAllCategories() => select(categories).watch();
  Future<Category?> getCategoryById(int? id) {
    if (id == null) return Future.value(null); // handle null ID
    return (select(
      categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);
  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);
  Future<int> deleteCategory(Category category) =>
      delete(categories).delete(category);

  // ============ EVENTS ============
  Future<List<Event>> getAllEvents() => select(events).get();
  Stream<List<Event>> watchAllEvents() => select(events).watch();
  Stream<List<Event>> watchUpcomingEvents() {
    final now = DateTime.now();

    // Start of today (00:00)
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    // End of tomorrow (23:59:59)
    final tomorrowEnd = todayStart
        .add(const Duration(days: 2))
        .subtract(const Duration(seconds: 1));

    return (select(events)
          ..where((e) => e.dueDate.isBetweenValues(todayStart, tomorrowEnd))
          ..orderBy([
            (e) => OrderingTerm(expression: e.dueDate), // first by due date
            (e) => OrderingTerm(expression: e.startTime), // then by start time
          ]))
        .watch();
  }

  Stream<List<Event>> watchEventsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(events)
          ..where((e) => e.dueDate.isBiggerOrEqualValue(startOfDay))
          ..where((e) => e.dueDate.isSmallerThanValue(endOfDay))
          ..orderBy([(e) => OrderingTerm.asc(e.startTime)]))
        .watch();
  }

  Stream<List<Event>> watchEventsForWeek(DateTime weekStart) {
    final startOfWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return (select(events)
          ..where((e) => e.dueDate.isBiggerOrEqualValue(startOfWeek))
          ..where((e) => e.dueDate.isSmallerThanValue(endOfWeek))
          ..orderBy([(e) => OrderingTerm.asc(e.startTime)]))
        .watch();
  }

  Future<int> insertEvent(EventsCompanion event) => into(events).insert(event);
  Future<bool> updateEvent(Event event) => update(events).replace(event);
  Future<int> deleteEvent(Event event) => delete(events).delete(event);
  // ============ TASKS ============
  Future<List<Task>> getAllTasks() => select(tasks).get();
  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Stream<List<Task>> watchTasksForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) => t.dueDate.isBiggerOrEqualValue(startOfDay))
          ..where((t) => t.dueDate.isSmallerThanValue(endOfDay))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .watch();
  }

  Stream<List<Task>> watchTodayTasks() => watchTasksForDate(DateTime.now());

  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);
  Future<bool> updateTask(Task task) => update(tasks).replace(task);
  Future<int> deleteTask(Task task) => delete(tasks).delete(task);

  Future<void> markTaskComplete(Task task) async {
    await (update(tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addTimeToTask(int taskId, int seconds) async {
    final task = await (select(
      tasks,
    )..where((t) => t.id.equals(taskId))).getSingle();
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(timeSpentSeconds: Value(task.timeSpentSeconds + seconds)),
    );
  }

  // ============ POMODORO SESSIONS ============
  Future<int> insertPomodoroSession(PomodoroSessionsCompanion session) =>
      into(pomodoroSessions).insert(session);

  Stream<List<PomodoroSession>> watchSessionsForTask(int taskId) =>
      (select(pomodoroSessions)..where((s) => s.taskId.equals(taskId))).watch();

  Future<int> getTotalFocusTimeSeconds() async {
    final sessions = await select(pomodoroSessions).get();
    return sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  Future<int> getFocusTimeInRange(DateTime start, DateTime end) async {
    final sessions =
        await (select(pomodoroSessions)
              ..where((s) => s.completedAt.isBiggerOrEqualValue(start))
              ..where((s) => s.completedAt.isSmallerThanValue(end)))
            .get();
    return sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  // ============ SETTINGS ============
  Future<AppSetting> getSettings() async {
    final result = await select(appSettings).getSingleOrNull();
    if (result == null) {
      await into(appSettings).insert(const AppSettingsCompanion());
      return (await select(appSettings).getSingle());
    }
    return result;
  }

  Stream<AppSetting> watchSettings() => select(appSettings).watchSingle();

  Future<void> updateSettings(AppSettingsCompanion settings) async {
    await (update(appSettings)..where((s) => s.id.equals(1))).write(settings);
  }

  // ============ STATISTICS ============
  Future<int> getCompletedTaskCount() async {
    final result = await (select(
      tasks,
    )..where((t) => t.isCompleted.equals(true))).get();
    return result.length;
  }

  Future<int> getIncompleteTaskCount() async {
    final result = await (select(
      tasks,
    )..where((t) => t.isCompleted.equals(false))).get();
    return result.length;
  }

  Future<List<Task>> getTasksInDateRange(DateTime start, DateTime end) {
    return (select(tasks)
          ..where((t) => t.dueDate.isBiggerOrEqualValue(start))
          ..where((t) => t.dueDate.isSmallerThanValue(end)))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'task_scheduler.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
