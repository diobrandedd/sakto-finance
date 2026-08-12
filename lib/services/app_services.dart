import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/app_database.dart';
import '../platform/file_support.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  String? _lastReminderDay;

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
  }

  Future<bool?> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidResult = await android?.requestNotificationsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosResult = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidResult ?? iosResult;
  }

  Future<void> remindDueLentMoney(List<LentMoneyData> items) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_lastReminderDay == today) return;
    _lastReminderDay = today;
    for (final item in items.where(
      (e) =>
          e.status == 'unpaid' &&
          !e.expectedReturnDate.isAfter(
            DateTime(now.year, now.month, now.day, 23, 59, 59),
          ),
    )) {
      final overdue = item.expectedReturnDate.isBefore(
        DateTime(now.year, now.month, now.day),
      );
      await _plugin.show(
        id: 10000 + item.id,
        title: overdue ? 'Repayment overdue' : 'Repayment due today',
        body:
            '${item.borrowerName} owes you ₱${item.amount.toStringAsFixed(2)}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'lent_money_reminders',
            'Lent money reminders',
            channelDescription: 'Due and overdue lent money reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> cancelLentReminder(int id) => _plugin.cancel(id: 10000 + id);
}

class BackupService {
  static Future<String> exportJson(AppDatabase database) async {
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final data = await database.exportSnapshot();
    return writeTextDocument(
      'sakto-$stamp.json',
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }
}
