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
  IntColumn get iconCodePoint => integer().nullable()(); // Material icon code
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
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Pomodoro session records for time tracking
class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id)();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// App settings (single row table)
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get pomodoroMinutes => integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  BoolColumn get hasSeenIntro => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Categories, Tasks, PomodoroSessions, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  // ============ CATEGORIES ============
  Future<List<Category>> getAllCategories() => select(categories).get();
  Stream<List<Category>> watchAllCategories() => select(categories).watch();
  Future<int> insertCategory(CategoriesCompanion category) =>
      into(categories).insert(category);
  Future<bool> updateCategory(Category category) =>
      update(categories).replace(category);
  Future<int> deleteCategory(Category category) =>
      delete(categories).delete(category);

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

  // ============ SETTINGS ============
  Future<AppSetting> getSettings() async {
    final result = await select(appSettings).getSingleOrNull();
    if (result == null) {
      await into(appSettings).insert(const AppSettingsCompanion());
      return (await select(appSettings).getSingle());
    }
    return result;
  }

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
