import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'today_tasks_screen.dart';
import 'calendar_screen.dart';
import 'pomodoro_screen.dart';
import 'report_screen.dart';

/// Main shell with bottom navigation.
///
/// Exposes a [tabNotifier] so external code (e.g.
/// notification tap handler) can switch tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Allows programmatically switching the active tab.
  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(1);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<Widget> _screens = const [
    PomodoroScreen(),
    TodayTasksScreen(),
    CalendarScreen(),
    ReportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    MainShell.tabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    MainShell.tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: MainShell.tabNotifier.value,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: MainShell.tabNotifier.value,
        onDestinationSelected: (index) {
          MainShell.tabNotifier.value = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      ),
    );
  }
}
