import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../data/database.dart';

/// ViewModel for managing tasks using MVVM pattern
class TaskViewModel extends ChangeNotifier {
  final AppDatabase _db;

  TaskViewModel(this._db);

  Stream<List<Task>> get todayTasks => _db.watchTodayTasks();
  Stream<List<Task>> get allTasks => _db.watchAllTasks();

  Stream<List<Task>> tasksForDate(DateTime date) => _db.watchTasksForDate(date);

  Future<void> addTask({
    required String title,
    String? description,
    required int color,
    required String priority,
    required DateTime dueDate,
    bool isRepeating = false,
    DateTime? repeatEndDate,
    int? categoryId,
  }) async {
    await _db.insertTask(
      TasksCompanion(
        title: Value(title),
        description: Value(description),
        color: Value(color),
        priority: Value(priority),
        dueDate: Value(dueDate),
        isRepeating: Value(isRepeating),
        repeatEndDate: Value(repeatEndDate),
        categoryId: Value(categoryId),
      ),
    );
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
    notifyListeners();
  }

  Future<void> deleteTask(Task task) async {
    await _db.deleteTask(task);
    notifyListeners();
  }

  Future<void> toggleTaskComplete(Task task) async {
    if (task.isCompleted) {
      await _db.updateTask(
        task.copyWith(isCompleted: false, completedAt: const Value(null)),
      );
    } else {
      await _db.markTaskComplete(task);
    }
    notifyListeners();
  }

  Future<void> addTimeToTask(int taskId, int seconds) async {
    await _db.addTimeToTask(taskId, seconds);
    notifyListeners();
  }

  Future<void> setManualTime(Task task, int totalSeconds) async {
    await _db.updateTask(task.copyWith(timeSpentSeconds: totalSeconds));
    notifyListeners();
  }
}
