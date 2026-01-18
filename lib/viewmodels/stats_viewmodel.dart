import 'package:flutter/foundation.dart';
import '../data/database.dart';

/// ViewModel for statistics and reporting
class StatsViewModel extends ChangeNotifier {
  final AppDatabase _db;

  StatsViewModel(this._db);

  Future<int> get totalFocusTimeSeconds => _db.getTotalFocusTimeSeconds();
  Future<int> get completedTaskCount => _db.getCompletedTaskCount();
  Future<int> get incompleteTaskCount => _db.getIncompleteTaskCount();

  Future<Map<String, dynamic>> getWeeklyStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final tasks = await _db.getTasksInDateRange(
      DateTime(weekStart.year, weekStart.month, weekStart.day),
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );

    // Group by day
    final Map<int, int> tasksPerDay = {};
    final Map<int, int> completedPerDay = {};

    for (var task in tasks) {
      final dayOfWeek = task.dueDate.weekday;
      tasksPerDay[dayOfWeek] = (tasksPerDay[dayOfWeek] ?? 0) + 1;
      if (task.isCompleted) {
        completedPerDay[dayOfWeek] = (completedPerDay[dayOfWeek] ?? 0) + 1;
      }
    }

    return {
      'tasksPerDay': tasksPerDay,
      'completedPerDay': completedPerDay,
      'totalTasks': tasks.length,
      'completedTasks': tasks.where((t) => t.isCompleted).length,
    };
  }

  Future<int> calculateDayStreak() async {
    final now = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final tasks = await _db.getTasksInDateRange(startOfDay, endOfDay);
      final hasCompletedTask = tasks.any((t) => t.isCompleted);

      if (hasCompletedTask) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return streak;
  }
}
