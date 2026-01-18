import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/database.dart';
import '../models/priority.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_card.dart';
import 'package:drift/drift.dart' as drift;

// Use global database from today_tasks_screen
import 'today_tasks_screen.dart' show database;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calendar',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                    icon: const Icon(Icons.today),
                    tooltip: 'Go to today',
                  ),
                ],
              ),
            ),

            // Calendar widget using StreamBuilder to get events
            StreamBuilder<List<Task>>(
              stream: database.watchAllTasks(),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];

                // Group tasks by date
                final Map<DateTime, List<Task>> tasksByDate = {};
                for (var task in tasks) {
                  final date = DateTime(
                    task.dueDate.year,
                    task.dueDate.month,
                    task.dueDate.day,
                  );
                  tasksByDate.putIfAbsent(date, () => []).add(task);
                }

                return TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final dayKey = DateTime(date.year, date.month, date.day);
                      final dayTasks = tasksByDate[dayKey] ?? [];

                      if (dayTasks.isEmpty) return null;

                      // Get highest priority color
                      Priority highestPriority = Priority.low;
                      for (var task in dayTasks) {
                        final p = Priority.fromString(task.priority);
                        if (p == Priority.high) {
                          highestPriority = Priority.high;
                          break;
                        } else if (p == Priority.medium &&
                            highestPriority != Priority.high) {
                          highestPriority = Priority.medium;
                        }
                      }

                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(highestPriority.colorHex),
                          ),
                        ),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                );
              },
            ),

            const Divider(height: 1),

            // Tasks for selected day
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: database.watchTasksForDate(_selectedDay),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data!;

                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No tasks for this day',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        onToggleComplete: () async {
                          if (task.isCompleted) {
                            await database.updateTask(
                              task.copyWith(
                                isCompleted: false,
                                completedAt: const drift.Value(null),
                              ),
                            );
                          } else {
                            await database.markTaskComplete(task);
                          }
                        },
                        onDelete: () async {
                          await database.deleteTask(task);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTaskDialog(
              initialDate: _selectedDay,
              onSave: (task) async {
                await database.insertTask(task);
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
