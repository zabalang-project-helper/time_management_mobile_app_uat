import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/database.dart';

/// Callback type for handling notification taps.
typedef NotificationTapCallback = void Function(String? payload);

/// Callback type for handling notification actions (snooze).
typedef NotificationActionCallback =
    void Function(String actionId, String? payload);

/// Manages all local notifications for the app.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when user taps a notification.
  NotificationTapCallback? onNotificationTap;

  // Notification IDs
  static const int _pomodoroOngoingId = 99990;
  static const int _pomodoroCompleteId = 99991;

  // Action IDs
  static const String snoozeActionId = 'snooze_10';

  void _log(String message) {
    if (kDebugMode) {
      print('[NotificationService] $message');
    }
  }

  /// Initializes the notification plugin, timezone,
  /// and sets the tap callback.
  Future<void> init({NotificationTapCallback? onTap}) async {
    _log('Initializing NotificationService...');
    onNotificationTap = onTap;
    tz.initializeTimeZones();

    try {
      final String timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      _log('Device Timezone: $timeZoneName');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      _log('Error setting local timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        _log('Fallback to UTC timezone');
      } catch (_) {}
    }

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    _log('Initialization complete.');
  }

  /// Handles both notification taps and action buttons.
  void _handleNotificationResponse(NotificationResponse details) {
    _log(
      'Notification response: '
      'actionId=${details.actionId}, '
      'payload=${details.payload}',
    );

    // Handle snooze action
    if (details.actionId == snoozeActionId) {
      final payload = details.payload;
      if (payload != null && payload.startsWith('task:')) {
        final parts = payload.split(':');
        if (parts.length >= 3) {
          final taskId = int.tryParse(parts[1]);
          final taskTitle = parts.sublist(2).join(':');
          if (taskId != null) {
            snoozeTaskReminder(taskId, taskTitle);
          }
        }
      }
      return;
    }

    // Handle regular tap
    onNotificationTap?.call(details.payload);
  }

  /// Requests notification permissions on Android 13+ and iOS.
  Future<void> requestPermissions() async {
    _log('Requesting permissions...');
    final bool? androidGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _log('Android Permission granted: $androidGranted');

    final bool? iosGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _log('iOS Permission granted: $iosGranted');
  }

  // ============ POMODORO NOTIFICATIONS ============

  /// Shows or updates the ongoing Pomodoro countdown
  /// notification.
  ///
  /// [modeLabel] is "Focus", "Short Break", or "Long Break".
  /// [remainingSeconds] is the current countdown value.
  Future<void> showOngoingPomodoro(
    String modeLabel,
    int remainingSeconds,
  ) async {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'pomodoro_ongoing_v1',
          'Pomodoro Timer',
          channelDescription: 'Ongoing countdown for Pomodoro sessions',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          playSound: false,
          enableVibration: false,
          onlyAlertOnce: true,
          category: AndroidNotificationCategory.progress,
          silent: true,
        );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentSound: false,
      ),
    );

    await _notificationsPlugin.show(
      id: _pomodoroOngoingId,
      title: 'Pomodoro Timer',
      body: '$modeLabel $minutes:$seconds',
      notificationDetails: details,
      payload: 'pomodoro',
    );
  }

  /// Fires a high-priority alert when the Pomodoro
  /// session completes.
  Future<void> showPomodoroComplete(String title, String body) async {
    _log('Showing Pomodoro complete: $title');

    // Cancel the ongoing notification first
    await cancelOngoingPomodoro();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'pomodoro_timer_v2',
          'Pomodoro Alerts',
          channelDescription: 'Alert when Pomodoro session completes',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: _pomodoroCompleteId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'pomodoro',
    );
  }

  /// Schedules a Pomodoro completion notification at
  /// the given time (backup for when app is killed).
  Future<void> schedulePomodoro(
    DateTime scheduledTime,
    String title,
    String body,
  ) async {
    if (scheduledTime.isBefore(DateTime.now())) {
      _log('Skipping past Pomodoro schedule.');
      return;
    }

    _log('Scheduling Pomodoro at $scheduledTime');
    try {
      await _notificationsPlugin.zonedSchedule(
        id: _pomodoroCompleteId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pomodoro_timer_v2',
            'Pomodoro Alerts',
            channelDescription: 'Alert when Pomodoro session completes',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'pomodoro',
      );
      _log('Pomodoro scheduled successfully.');
    } catch (e) {
      _log('Error scheduling pomodoro: $e');
    }
  }

  /// Cancels the ongoing countdown notification.
  Future<void> cancelOngoingPomodoro() async {
    _log('Cancelling ongoing Pomodoro notification');
    await _notificationsPlugin.cancel(id: _pomodoroOngoingId);
  }

  /// Cancels both ongoing and scheduled Pomodoro
  /// notifications.
  Future<void> cancelPomodoro() async {
    _log('Cancelling all Pomodoro notifications');
    await _notificationsPlugin.cancel(id: _pomodoroOngoingId);
    await _notificationsPlugin.cancel(id: _pomodoroCompleteId);
  }

  // ============ TASK REMINDER NOTIFICATIONS ============

  /// Schedules a task reminder notification.
  ///
  /// Uses [task.reminderMinutesBefore] to fire the
  /// notification before the due date.
  Future<void> scheduleTaskReminder(Task task) async {
    if (!task.isReminderActive || task.isCompleted) {
      return;
    }

    final reminderTime = task.dueDate.subtract(
      Duration(minutes: task.reminderMinutesBefore),
    );

    if (reminderTime.isBefore(DateTime.now())) {
      _log('Skipping past reminder for: ${task.title}');
      return;
    }

    _log(
      'Scheduling reminder for: ${task.title} '
      'at $reminderTime '
      '(${task.reminderMinutesBefore} min before due)',
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: task.id,
        title: '⏰ Task Reminder',
        body: task.title,
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_v2',
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                snoozeActionId,
                'Snooze 10 min',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task:${task.id}:${task.title}',
      );
      _log('Task reminder scheduled successfully.');
    } catch (e) {
      _log('Error scheduling task reminder: $e');
    }
  }

  /// Snoozes a task reminder by 10 minutes from now.
  Future<void> snoozeTaskReminder(
    int taskId,
    String taskTitle, {
    int snoozeMinutes = 10,
  }) async {
    _log('Snoozing task $taskId for $snoozeMinutes min');

    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));

    try {
      await _notificationsPlugin.zonedSchedule(
        id: taskId,
        title: '⏰ Task Reminder (Snoozed)',
        body: taskTitle,
        scheduledDate: tz.TZDateTime.from(snoozeTime, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders_v2',
            'Task Reminders',
            channelDescription: 'Notifications for task reminders',
            importance: Importance.high,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                snoozeActionId,
                'Snooze 10 min',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'task:$taskId:$taskTitle',
      );
      _log('Snoozed reminder scheduled at $snoozeTime');
    } catch (e) {
      _log('Error snoozing task reminder: $e');
    }
  }

  /// Cancels a task reminder by task ID.
  Future<void> cancelTaskReminder(int taskId) async {
    _log('Cancelling reminder for task ID: $taskId');
    await _notificationsPlugin.cancel(id: taskId);
  }
}
