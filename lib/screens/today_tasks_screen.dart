import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_card.dart';

// Global database instance
final database = AppDatabase();

class TodayTasksScreen extends StatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  void _showAddTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskDialog(
        onSave: (tasks) async {
          await database.batch((batch) {
            for (var task in tasks) {
              batch.insert(database.tasks, task);
            }
          });
        },
      ),
    );
  }

  Future<void> _toggleComplete(Task task) async {
    if (task.isCompleted) {
      await database.updateTask(
        task.copyWith(isCompleted: false, completedAt: const drift.Value(null)),
      );
    } else {
      await database.markTaskComplete(task);
    }
  }

  Future<void> _deleteTask(Task task) async {
    bool deleteFuture = false;
    bool confirmDelete = true;

    if (task.repeatId != null) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Repeating Task'),
          content: const Text(
            'This is a repeating task. Do you want to delete only this instance or this and all future instances?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'single'),
              child: const Text('This Only'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'future'),
              child: const Text('This and Future'),
            ),
          ],
        ),
      );

      if (result == 'cancel' || result == null) {
        confirmDelete = false;
      } else if (result == 'future') {
        deleteFuture = true;
      }
    }

    if (confirmDelete) {
      if (deleteFuture && task.repeatId != null) {
        // Delete this task and all future tasks with same repeatId
        await (database.delete(database.tasks)..where(
              (t) =>
                  t.repeatId.equals(task.repeatId!) &
                  t.dueDate.isBiggerOrEqualValue(task.dueDate),
            ))
            .go();
      } else {
        await database.deleteTask(task);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${task.title}"'),
            // Simplified Undo for now as batch undo is complex
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _undoDelete(task),
            ),
          ),
        );
      }
    }
  }

  // Separate undo method for cleaner code, though batch undo is not fully implemented for loops
  Future<void> _undoDelete(Task task) async {
    await database.insertTask(
      TasksCompanion(
        title: drift.Value(task.title),
        description: drift.Value(task.description),
        color: drift.Value(task.color),
        priority: drift.Value(task.priority),
        dueDate: drift.Value(task.dueDate),
        isCompleted: drift.Value(task.isCompleted),
        timeSpentSeconds: drift.Value(task.timeSpentSeconds),
        repeatId: drift.Value(task.repeatId),
        isRepeating: drift.Value(task.isRepeating),
        repeatEndDate: drift.Value(task.repeatEndDate),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Today's Tasks",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Task list
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: database.watchTodayTasks(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data!;
                  final todoTasks = tasks.where((t) => !t.isCompleted).toList();
                  final completedTasks = tasks
                      .where((t) => t.isCompleted)
                      .toList();

                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks for today',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showAddTaskDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add your first task'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // To Do section
                      if (todoTasks.isNotEmpty) ...[
                        _buildSectionHeader(
                          'To Do',
                          todoTasks.length,
                          AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 8),
                        ...todoTasks.map(
                          (task) => TaskCard(
                            task: task,
                            onToggleComplete: () => _toggleComplete(task),
                            onDelete: () => _deleteTask(task),
                            onTap: () => _showEditTaskDialog(task),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Completed section
                      if (completedTasks.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Completed',
                          completedTasks.length,
                          AppTheme.successColor,
                        ),
                        const SizedBox(height: 8),
                        ...completedTasks.map(
                          (task) => TaskCard(
                            task: task,
                            onToggleComplete: () => _toggleComplete(task),
                            onDelete: () => _deleteTask(task),
                            onTap: () => _showEditTaskDialog(task),
                            showTimeSpent: true,
                            timeSpentFormatted: _formatDuration(
                              task.timeSpentSeconds,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 80), // FAB space
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditTaskDialog(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskDialog(
        existingTask: task,
        onSave: (companions) async {
          // Basic handle: delete old and insert new.
          // NOTE: This will reset task stats if we're not careful, but for MVP repeat logic rewrite it handles "Conversion"
          // For single edit (list 1), we can try to update.

          if (companions.length == 1 &&
              companions.first.repeatId.value == null) {
            // Single task update (or detached from repeat)
            final companion = companions.first;
            await database.updateTask(
              task.copyWith(
                title: companion.title.value,
                description: drift.Value(companion.description.value),
                color: companion.color.value,
                priority: companion.priority.value,
                dueDate: companion.dueDate.value,
                isRepeating: companion.isRepeating.value,
                repeatEndDate: companion.repeatEndDate.present
                    ? drift.Value(companion.repeatEndDate.value)
                    : drift.Value(task.repeatEndDate),
                categoryId: companion.categoryId.present
                    ? drift.Value(companion.categoryId.value)
                    : drift.Value(task.categoryId),
                repeatId: drift.Value(null), // Detach if single update
              ),
            );
          } else {
            // Multi-task insert implies rewrite/new series.
            // Delete the OLD task (this instance).
            await database.deleteTask(task);

            // Insert all New
            await database.batch((batch) {
              for (var c in companions) {
                batch.insert(database.tasks, c);
              }
            });
          }
        },
      ),
    );
  }
}
