import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call this ONCE in main()
  Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);
  }

  /// Schedule reminder for BOTH Event & Task
  Future<void> scheduleReminder({
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) {
      return; // don't schedule past notifications
    }

    final tzDateTime = tz.TZDateTime.from(scheduledAt, tz.local);

    await _plugin.zonedSchedule(
      id: scheduledAt.millisecondsSinceEpoch ~/ 1000, // unique ID
      title: title,
      body: body,
      scheduledDate: tzDateTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          channelDescription: 'Event & Task reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// Cancel reminder (used on delete or edit)
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
  }
}
