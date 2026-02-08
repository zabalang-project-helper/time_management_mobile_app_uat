import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:time_management_mobile_app/widgets/add_category_dialog.dart';
import 'package:time_management_mobile_app/widgets/add_event_dialog.dart';
import 'package:time_management_mobile_app/widgets/event_card.dart';
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
  bool _fabOpen = false;
  bool _showWeeklyTimetable = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  PageController _weekPageController = PageController(initialPage: 0);
  int _currentWeekOffset = 0; // 0 = this week, +1 next, -1 previous
  DateTime _currentWeekStart = DateTime.now(); // start date of the currently visible week

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${task.title}"')));
      }
    }
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

  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          if (_fabOpen) ...[
            _fabChild(
              label: _showWeeklyTimetable ? "Calendar View" : "Weekly Timetable",
              icon: _showWeeklyTimetable ? Icons.calendar_month : Icons.view_week,
              onTap: () {
                setState(() {
                  if (!_showWeeklyTimetable) {
                    _selectedDay = _focusedDay;
                  }
                  _showWeeklyTimetable = !_showWeeklyTimetable;
                  _fabOpen = false;
                });
              },
            ),

            const SizedBox(height: 10),

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

  Widget _buildBody() {
    return _showWeeklyTimetable
        ? _buildWeeklyTimetable()
        : _buildCalendarView();
  }

  List<TimetableItem<Event>> _mapEventsToItems(List<Event> events) {
    return events.map((e) {
      return TimetableItem(
        e.startTime,
        e.endTime,
        data: e,
      );
    }).toList();
  }

  Widget _buildWeeklyTimetable() {
    const initialPage = 5000; // big number to allow scrolling backward
    _weekPageController = PageController(initialPage: initialPage);

    return Column(
      children: [
        // --- Header ---
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Timetable',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  // Previous Week
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _currentWeekOffset--;
                        _currentWeekStart = _weekStart(
                          DateTime.now().add(Duration(days: _currentWeekOffset * 7)),
                        );
                      });
                      _weekPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  // Today
                  IconButton(
                    icon: const Icon(Icons.today),
                    onPressed: () {
                      setState(() {
                        _currentWeekOffset = 0;
                        _currentWeekStart = _weekStart(DateTime.now());
                      });
                      _weekPageController.jumpToPage(initialPage);
                    },
                  ),
                  // Next Week
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _currentWeekOffset++;
                        _currentWeekStart = _weekStart(
                          DateTime.now().add(Duration(days: _currentWeekOffset * 7)),
                        );
                      });
                      _weekPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // --- Timetable PageView ---
        Expanded(
          child: PageView.builder(
            controller: _weekPageController,
            onPageChanged: (pageIndex) {
              setState(() {
                _currentWeekOffset = pageIndex - initialPage;
                _currentWeekStart = _weekStart(
                  DateTime.now().add(Duration(days: _currentWeekOffset * 7)),
                );
              });
            },
            itemBuilder: (context, pageIndex) {
              final weekOffset = pageIndex - initialPage;
              final weekStart = _weekStart(
                DateTime.now().add(Duration(days: weekOffset * 7)),
              );

              return StreamBuilder<List<Event>>(
                stream: database.watchEventsForWeek(weekStart),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final events = snapshot.data!;
                  final items = _mapEventsToItems(events);

                  final controller = TimetableController(
                    start: weekStart,
                    initialColumns: 7,
                    cellHeight: 60.0,
                    startHour: 5,
                    endHour: 22,
                  );

                  return Timetable<Event>(
                    controller: controller,
                    items: items,
                    snapToDay: true,
                    nowIndicatorColor: Colors.red,
                    cellBuilder: (datetime) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 0.3),
                      ),
                    ),
                    itemBuilder: (item) => GestureDetector(
                      onTap: () => _showEditEventDialog(item.data!),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Color(item.data!.color).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            item.data!.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    headerCellBuilder: (datetime) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat.E().format(datetime),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat.d().format(datetime),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    hourLabelBuilder: (time) {
                      final hour = time.hour;
                      final ampm = hour < 12 ? "am" : "pm";
                      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Text(
                          "$displayHour$ampm",
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    return SafeArea(
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
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
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
                      defaultTextStyle: const TextStyle(
                        color: Colors.white,
                      ),
                      weekendTextStyle: const TextStyle(
                        color: Colors.white,
                      ),
                      outsideTextStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
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
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                );
              },
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Event",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ===== Events =====
                  StreamBuilder<List<Event>>(
                    stream: database.watchEventsForDate(_selectedDay),
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
                                "No event for this day",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final upcomingEvents = events;

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

                            const SizedBox(height: 4),
                          ],
                        ),
                      );
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Task",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // ===== Tasks for selected day =====
                  StreamBuilder<List<Task>>(
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

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...tasks.map(
                              (task) => TaskCard(
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
                                onDelete: () => _deleteTask(task),
                                onTap: () => _showEditTaskDialog(task),
                              )
                            ),
                            const SizedBox(height: 24),
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
    );
  }
}
