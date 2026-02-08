import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_management_mobile_app/widgets/add_category_dialog.dart';
import 'package:time_management_mobile_app/widgets/add_event_dialog.dart';
import 'package:time_management_mobile_app/widgets/event_card.dart';
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
  bool _fabOpen = false;

  void _showAddCategoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCategoryDialog(
        onSave: (categories) async {
          await database.batch((batch) {
            for (var category in categories) {
              batch.insert(database.categories, category);
            }
          });
        },
      ),
    );
  }

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

  void _showAddEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventDialog(
        onSave: (events) async {
          await database.batch((batch) {
            for (var event in events) {
              batch.insert(database.events, event);
            }
          });
        },
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      await database.deleteEvent(event); // call your Drift delete method
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete event: $e")),
      );
    }
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

    String getTodayText() {
      final now = DateTime.now();

      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ];

      final dayName = days[now.weekday % 7];

      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = (now.year % 100).toString().padLeft(2, '0');

      return "$dayName, $day/$month/$year";
    }

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
                    getTodayText(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Upcoming Events",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ===== Events =====
                  StreamBuilder<List<Event>>(
                    stream: database.watchUpcomingEvents(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final events = snapshot.data!;

                      if (events.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No upcoming events",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "For today and tomorrow",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final upcomingEvents = events.where(  
                        (e) => e.dueDate.isBefore(
                          DateTime.now().add(const Duration(days: 2)),
                        ),
                      ).toList();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            ...upcomingEvents.map(
                              (e) => EventCard(
                                event: e, 
                                onDelete: () => _deleteEvent(e),
                                onTap: () => _showEditEventDialog(e)
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Today's Tasks",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ===== Tasks =====
                  StreamBuilder<List<Task>>(
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
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No tasks yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Tap + to add your first task",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [

                            if (todoTasks.isNotEmpty) ...[
                              _buildSectionHeader(
                                'To Do',
                                todoTasks.length,
                                AppTheme.primaryColor,
                              ),
                              const SizedBox(height: 8),
                              ...todoTasks.map((task) => TaskCard(
                                    task: task,
                                    onToggleComplete: () => _toggleComplete(task),
                                    onDelete: () => _deleteTask(task),
                                    onTap: () => _showEditTaskDialog(task),
                                  )),
                              const SizedBox(height: 24),
                            ],

                            if (completedTasks.isNotEmpty) ...[
                              _buildSectionHeader(
                                'Completed',
                                completedTasks.length,
                                AppTheme.successColor,
                              ),
                              const SizedBox(height: 8),
                              ...completedTasks.map((task) => TaskCard(
                                    task: task,
                                    onToggleComplete: () => _toggleComplete(task),
                                    onDelete: () => _deleteTask(task),
                                    onTap: () => _showEditTaskDialog(task),
                                    showTimeSpent: true,
                                    timeSpentFormatted:
                                        _formatDuration(task.timeSpentSeconds),
                                  )),
                            ],

                            const SizedBox(height: 80),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          if (_fabOpen) ...[
            _fabChild(
              label: "Add Category",
              icon: Icons.category,
              onTap: () {
                setState(() => _fabOpen = false);
                _showAddCategoryDialog();
              },
            ),

            const SizedBox(height: 10),

            _fabChild(
              label: "Add Event",
              icon: Icons.event,
              onTap: () {
                setState(() => _fabOpen = false);
                _showAddEventDialog();
              },
            ),

            const SizedBox(height: 10),

            _fabChild(
              label: "Add Task",
              icon: Icons.task,
              onTap: () {
                setState(() => _fabOpen = false);
                _showAddTaskDialog();
              },
            ),

            const SizedBox(height: 20),
          ],

          FloatingActionButton(
            onPressed: () {
              setState(() => _fabOpen = !_fabOpen);
            },
            child: Icon(_fabOpen ? Icons.close : Icons.add),
          ),
        ],
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

  Widget _fabChild({required String label, required IconData icon, required VoidCallback onTap,}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),

        const SizedBox(width: 8),

        FloatingActionButton(
          mini: true,
          heroTag: null,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }

  void _showEditEventDialog(Event event) {
    print("Editing event: ${event.title}");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEventDialog(
        existingEvent: event,
        onSave: (companions) async {
          // Basic handle: delete old and insert new.
          // NOTE: This will reset task stats if we're not careful, but for MVP repeat logic rewrite it handles "Conversion"
          // For single edit (list 1), we can try to update.

          if (companions.length == 1 &&
              companions.first.repeatId.value == null) {
            // Single event update logic
            final updatedEvent = companions.first;
            await database.updateEvent(
              event.copyWith(
                title: updatedEvent.title.value,
                description: drift.Value(updatedEvent.description.value),
                color: updatedEvent.color.value,
                dueDate: updatedEvent.dueDate.value,
                startTime: updatedEvent.startTime.value,
                endTime: updatedEvent.endTime.value,
                durationMinutes: updatedEvent.durationMinutes.value,
                isRepeating: updatedEvent.isRepeating.value,
                repeatEndDate: updatedEvent.repeatEndDate.present
                    ? drift.Value(updatedEvent.repeatEndDate.value)
                    : drift.Value(event.repeatEndDate),
                categoryId: updatedEvent.categoryId.present
                    ? drift.Value(updatedEvent.categoryId.value)
                    : drift.Value(event.categoryId),
                repeatId: drift.Value(null), // Detach if single update
                isReminding: updatedEvent.isReminding.value,
              ),
            );
          }else {
            // Multi-task insert implies rewrite/new series.
            // Delete the OLD task (this instance).
            await database.deleteEvent(event);

            // Insert all New
            await database.batch((batch) {
              for (var c in companions) {
                batch.insert(database.events, c);
              }
            });
          }
        },
      ),
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
                isReminding: companion.isReminding.value,
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
