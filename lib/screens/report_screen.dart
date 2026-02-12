import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database.dart';
import '../theme/app_theme.dart';
import 'today_tasks_screen.dart' show database;

enum DateFilter { today, thisWeek, allTime, custom }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateFilter _selectedFilter = DateFilter.today;
  DateTimeRange? _customDateRange;

  // Cache for the current date range to query
  DateTimeRange _getCurrentRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case DateFilter.today:
        return DateTimeRange(
          start: todayStart,
          end: todayStart.add(const Duration(days: 1)),
        );
      case DateFilter.thisWeek:
        // Assuming week starts on Monday
        final startOfWeek = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        return DateTimeRange(
          start: startOfWeek,
          end: startOfWeek.add(const Duration(days: 7)),
        );
      case DateFilter.allTime:
        // Distant past to distant future
        return DateTimeRange(start: DateTime(2020), end: DateTime(2030));
      case DateFilter.custom:
        return _customDateRange ??
            DateTimeRange(
              start: todayStart,
              end: todayStart.add(const Duration(days: 1)),
            );
    }
  }

  String _getFilterLabel(DateFilter filter) {
    switch (filter) {
      case DateFilter.today:
        return 'Today';
      case DateFilter.thisWeek:
        return 'This Week';
      case DateFilter.allTime:
        return 'All Time';
      case DateFilter.custom:
        return 'Custom';
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange,
      saveText: 'Apply',
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedFilter = DateFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _getCurrentRange();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Task>>(
          stream: database.watchAllTasks(),
          builder: (context, tasksSnapshot) {
            final allTasks = tasksSnapshot.data ?? [];

            // Filter tasks by the selected range (using DueDate)
            // Note: For All Time, we assume all tasks. For others, due date check.
            final rangeTasks = _selectedFilter == DateFilter.allTime
                ? allTasks
                : allTasks.where((t) {
                    return t.dueDate.isBefore(range.end) &&
                        t.dueDate.isAfter(
                          range.start.subtract(const Duration(seconds: 1)),
                        );
                  }).toList();

            // Calculate Counts
            final completedCount = rangeTasks
                .where((t) => t.isCompleted)
                .length;
            final incompleteCount = rangeTasks
                .where((t) => !t.isCompleted)
                .length;
            final totalCount = rangeTasks.length;
            final completionRate = totalCount == 0
                ? 0
                : ((completedCount / totalCount) * 100).round();

            // Calculate Weekly Data (Always show this week's activity regardless of filter?
            // Or show distribution within the selected range?)
            // The prompt asked for "Weekly Overview" previously. Let's keep "Weekly Overview" generally available
            // or adapt it. Let's keep standard weekly overview from "Now" for context, separate from filter.
            // OR if filter is week, show that week.
            // Let's stick to "Weekly Overview" as "Last 7 Days" or "This Week" always for the chart,
            // otherwise a bar chart for "Today" is 1 bar.
            final weeklyData = _calculateWeeklyData(allTasks);

            return FutureBuilder<Map<String, dynamic>>(
              future: _getAsyncStats(range),
              builder: (context, statsSnapshot) {
                final focusSeconds = statsSnapshot.data?['focusSeconds'] ?? 0;
                final streak = statsSnapshot.data?['streak'] ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Filter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statistics',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          PopupMenuButton<DateFilter>(
                            initialValue: _selectedFilter,
                            onSelected: (DateFilter item) {
                              if (item == DateFilter.custom) {
                                _pickCustomRange();
                              } else {
                                setState(() => _selectedFilter = item);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _getFilterLabel(_selectedFilter),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ],
                              ),
                            ),
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<DateFilter>>[
                                  const PopupMenuItem<DateFilter>(
                                    value: DateFilter.today,
                                    child: Text('Today'),
                                  ),
                                  const PopupMenuItem<DateFilter>(
                                    value: DateFilter.thisWeek,
                                    child: Text('This Week'),
                                  ),
                                  const PopupMenuItem<DateFilter>(
                                    value: DateFilter.allTime,
                                    child: Text('All Time'),
                                  ),
                                  const PopupMenuItem<DateFilter>(
                                    value: DateFilter.custom,
                                    child: Text('Custom Range...'),
                                  ),
                                ],
                          ),
                        ],
                      ),
                      // Settings Section (Theme)
                      _buildSettingsSection(context),
                      const SizedBox(height: 24),

                      // Range Display Text
                      if (_selectedFilter == DateFilter.custom &&
                          _customDateRange != null)
                        Text(
                          '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Main Stats Grid
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            icon: Icons.timer,
                            iconColor: AppTheme.primaryColor,
                            title: 'Focus Time',
                            value: _formatDuration(focusSeconds),
                            width:
                                (MediaQuery.of(context).size.width - 52) /
                                2, // 2 columns
                          ),
                          _StatCard(
                            icon: Icons.check_circle_outline,
                            iconColor: AppTheme.successColor,
                            title: 'Completion Rate',
                            value: '$completionRate%',
                            width: (MediaQuery.of(context).size.width - 52) / 2,
                          ),
                          _StatCard(
                            icon: Icons.task_alt,
                            iconColor: AppTheme.successColor,
                            title: 'Completed',
                            value: '$completedCount',
                            width: (MediaQuery.of(context).size.width - 52) / 2,
                          ),
                          _StatCard(
                            icon: Icons.pending_actions,
                            iconColor: AppTheme.warningColor,
                            title: 'Incomplete',
                            value: '$incompleteCount',
                            width: (MediaQuery.of(context).size.width - 52) / 2,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // "Day Streak" is global, maybe separate it or put it in context
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: AppTheme.accentColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$streak Day Streak',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Keep the momentum going!',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Pie chart
                      const Text(
                        'Task Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPieChart(
                        completedCount,
                        incompleteCount,
                        totalCount,
                      ),
                      const SizedBox(height: 32),

                      // Bar chart - Weekly tasks (Always show "This Week" for context, or range?)
                      // Let's stick to "This Week" overview as it's a standard dashboard element.
                      const Text(
                        'Weekly Overview (Activity)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBarChart(weeklyData),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getAsyncStats(DateTimeRange range) async {
    final focusSeconds = await database.getFocusTimeInRange(
      range.start,
      range.end,
    );

    // Streak is always "Current Streak", not range dependent really
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final tasks = await database.getTasksInDateRange(startOfDay, endOfDay);
      final hasCompletedTask = tasks.any((t) => t.isCompleted);

      if (hasCompletedTask) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    return {'focusSeconds': focusSeconds, 'streak': streak};
  }

  Map<int, int> _calculateWeeklyData(List<Task> allTasks) {
    final now = DateTime.now();
    // Start of week (Monday)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final Map<int, int> weeklyData = {};

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      ).add(Duration(days: i));

      final dayTasks = allTasks.where((t) {
        final taskDate = DateTime(
          t.dueDate.year,
          t.dueDate.month,
          t.dueDate.day,
        );
        return taskDate.isAtSameMomentAs(date);
      }).length;

      weeklyData[i + 1] = dayTasks;
    }
    return weeklyData;
  }

  Widget _buildPieChart(int completed, int incomplete, int total) {
    if (total == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No tasks in this range',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: completed.toDouble(),
                    color: AppTheme.successColor,
                    title: '${((completed / total) * 100).round()}%',
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: incomplete.toDouble(),
                    color: Colors.grey.shade300,
                    title: '${((incomplete / total) * 100).round()}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(color: AppTheme.successColor, label: 'Completed'),
              const SizedBox(height: 8),
              _LegendItem(color: Colors.grey.shade300, label: 'Incomplete'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<int, int> data) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (data.isEmpty || data.values.every((v) => v == 0)) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No data this week',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (data.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} tasks',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(7, (index) {
            final dayOfWeek = index + 1;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (data[dayOfWeek] ?? 0).toDouble(),
                  color: AppTheme.primaryColor,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
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

  Widget _buildSettingsSection(BuildContext context) {
    return StreamBuilder<AppSetting>(
      stream: database.watchSettings(),
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null) return const SizedBox.shrink();

        final themeMode = settings.themeMode;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'App Theme',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('System')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    database.updateSettings(
                      AppSettingsCompanion(themeMode: drift.Value(value)),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final double? width;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
