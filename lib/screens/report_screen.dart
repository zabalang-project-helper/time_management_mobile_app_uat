import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import 'today_tasks_screen.dart' show database;

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Summary cards
              FutureBuilder<Map<String, int>>(
                future: _getStats(),
                builder: (context, snapshot) {
                  final stats =
                      snapshot.data ??
                      {
                        'total': 0,
                        'completed': 0,
                        'incomplete': 0,
                        'focusSeconds': 0,
                        'streak': 0,
                      };

                  return Column(
                    children: [
                      // Focus time and streak row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.timer,
                              iconColor: AppTheme.primaryColor,
                              title: 'Focus Time',
                              value: _formatDuration(stats['focusSeconds']!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_fire_department,
                              iconColor: AppTheme.accentColor,
                              title: 'Day Streak',
                              value: '${stats['streak']} days',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tasks row
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.task_alt,
                              iconColor: AppTheme.successColor,
                              title: 'Completed',
                              value: '${stats['completed']}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.pending_actions,
                              iconColor: AppTheme.warningColor,
                              title: 'Incomplete',
                              value: '${stats['incomplete']}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Pie chart
              const Text(
                'Task Completion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, int>>(
                future: _getStats(),
                builder: (context, snapshot) {
                  final stats =
                      snapshot.data ?? {'completed': 0, 'incomplete': 0};
                  final completed = stats['completed']!;
                  final incomplete = stats['incomplete']!;
                  final total = completed + incomplete;

                  if (total == 0) {
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Text(
                        'No tasks yet',
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
                                  title:
                                      '${((completed / total) * 100).round()}%',
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: incomplete.toDouble(),
                                  color: Colors.grey.shade300,
                                  title:
                                      '${((incomplete / total) * 100).round()}%',
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
                            _LegendItem(
                              color: AppTheme.successColor,
                              label: 'Completed',
                            ),
                            const SizedBox(height: 8),
                            _LegendItem(
                              color: Colors.grey.shade300,
                              label: 'Incomplete',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Bar chart - Weekly tasks
              const Text(
                'Weekly Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<int, int>>(
                future: _getWeeklyData(),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {};
                  final days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];

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
                        maxY: (data.values.reduce((a, b) => a > b ? a : b) + 2)
                            .toDouble(),
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
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, int>> _getStats() async {
    final completed = await database.getCompletedTaskCount();
    final incomplete = await database.getIncompleteTaskCount();
    final focusSeconds = await database.getTotalFocusTimeSeconds();

    // Calculate streak
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

    return {
      'total': completed + incomplete,
      'completed': completed,
      'incomplete': incomplete,
      'focusSeconds': focusSeconds,
      'streak': streak,
    };
  }

  Future<Map<int, int>> _getWeeklyData() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final Map<int, int> data = {};

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      ).add(Duration(days: i));
      final endOfDay = date.add(const Duration(days: 1));
      final tasks = await database.getTasksInDateRange(date, endOfDay);
      data[i + 1] = tasks.length;
    }

    return data;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
