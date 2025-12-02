// lib/notifications/notification_helper.dart
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';

/// NotificationHelper
/// - Schedules "one-day-before" reminders and optional expiry-day alerts
/// - Uses deterministic notification IDs so cancellation/rescheduling is easy
/// - Subscribes to Supabase Postgres realtime (v2.x API)
class NotificationHelper {
  // notification instance
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // realtime channel
  static RealtimeChannel? itemsChannel;

  // -------------------------------------------------------
  // INITIALIZE
  // -------------------------------------------------------
  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );

    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        // Handle tap → Navigate if needed (use navigatorKey in your app)
        print("Notification tapped. Payload: $payload");
      },
    );
  }

  // -------------------------------------------------------
  // REQUEST PERMISSIONS
  // -------------------------------------------------------
  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // optional: request exact alarms if you need them (Android 12+)
      try {
        await notificationsPlugin
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
            ?.requestExactAlarmsPermission();
      } catch (_) {
        // Not all plugin versions/platforms expose this; ignore if unavailable
      }
    } else {
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // -------------------------------------------------------
  // ID HELPERS (deterministic ids)
  // -------------------------------------------------------
  static int _baseIdFromItemId(String itemId) =>
      itemId.hashCode & 0x7fffffff; // positive

  static int _expiryIdFromBase(int base) => base ^ 0x10000000;
  static int _reminderIdFromBase(int base) => base;

  // -------------------------------------------------------
  // TIME HELPERS
  // -------------------------------------------------------
  /// returns tz.TZDateTime at previous day at given hour/minute
  static tz.TZDateTime _scheduledOneDayBefore(
      DateTime expiresOn, {
        int hour = 9,
        int minute = 0,
        bool sameTimePreviousDay = false,
      }) {
    final tzExpiry = tz.TZDateTime.from(expiresOn, tz.local);

    if (sameTimePreviousDay) {
      final prev = tzExpiry.subtract(const Duration(days: 1));
      return tz.TZDateTime(
        tz.local,
        prev.year,
        prev.month,
        prev.day,
        prev.hour,
        prev.minute,
      );
    }

    final scheduled = tzExpiry.subtract(const Duration(days: 1));
    return tz.TZDateTime(
      tz.local,
      scheduled.year,
      scheduled.month,
      scheduled.day,
      hour,
      minute,
    );
  }

  // -------------------------------------------------------
  // SCHEDULE EXPIRY NOTIFICATION (expiry-day)
  // -------------------------------------------------------
  static Future<void> scheduleExpiryNotification({
    required String itemId,
    required String itemName,
    required DateTime expiresOn,
    required int notificationId,
  }) async {
    final when = tz.TZDateTime.from(expiresOn, tz.local);

    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      return; // skip past dates
    }

    final androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Expiry Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final iosDetails = DarwinNotificationDetails();

    await notificationsPlugin.zonedSchedule(
      notificationId,
      'Expired: $itemName',
      '$itemName expired on ${expiresOn.toLocal().toString().split(" ").first}',
      when,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: itemId,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // -------------------------------------------------------
  // SCHEDULE ONE-DAY-BEFORE REMINDER
  // -------------------------------------------------------
  static Future<void> scheduleOneDayBeforeReminder({
    required String itemId,
    required String itemName,
    required DateTime expiresOn,
    required int notificationId,
    int remindHour = 9,
    int remindMinute = 0,
    bool sameTimePreviousDay = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final when = _scheduledOneDayBefore(
      expiresOn,
      hour: remindHour,
      minute: remindMinute,
      sameTimePreviousDay: sameTimePreviousDay,
    );

    if (when.isBefore(now)) {
      // If expiry still in future and within 24 hours, show immediate fallback
      final expiresTz = tz.TZDateTime.from(expiresOn, tz.local);
      final diff = expiresTz.difference(now);
      if (expiresTz.isAfter(now) && diff <= const Duration(hours: 24)) {
        await notificationsPlugin.show(
          notificationId,
          'Reminder: $itemName will expire soon',
          '$itemName expires on ${expiresOn.toLocal().toString().split(" ").first}.',
          NotificationDetails(
            android: AndroidNotificationDetails('expiry_reminder_channel', 'Expiry Reminders'),
            iOS: DarwinNotificationDetails(),
          ),
          payload: itemId,
        );
      }
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'expiry_reminder_channel',
      'Expiry Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();

    await notificationsPlugin.zonedSchedule(
      notificationId,
      'Reminder: $itemName will expire soon',
      '$itemName expires on ${expiresOn.toLocal().toString().split(" ").first}.',
      when,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: itemId,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }


  // -------------------------------------------------------
  // CANCEL FOR ONE ITEM (both reminder and expiry)
  // -------------------------------------------------------
  static Future<void> cancelItemNotification(String itemId) async {
    final base = _baseIdFromItemId(itemId);
    final reminderId = _reminderIdFromBase(base);
    final expiryId = _expiryIdFromBase(base);

    try {
      await notificationsPlugin.cancel(reminderId);
    } catch (_) {}
    try {
      await notificationsPlugin.cancel(expiryId);
    } catch (_) {}
  }

  // -------------------------------------------------------
  // FETCH ALL ITEMS AND SCHEDULE (idempotent)
  // - mode: "reminderOnly" or "both"
  // -------------------------------------------------------
  static Future<void> fetchAndScheduleAll({
    bool scheduleReminderOnly = true,
    int remindHour = 9,
    int remindMinute = 0,
    bool sameTimePreviousDay = false,
    int limitToNextN = 0, // 0 => no limit
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final List items = await supabase.from('items').select('id, name, expires_on');

      // optional: sort by expires_on and optionally limit
      items.sort((a, b) {
        final aRaw = a['expires_on'];
        final bRaw = b['expires_on'];
        if (aRaw == null && bRaw == null) return 0;
        if (aRaw == null) return 1;
        if (bRaw == null) return -1;
        final aDt = DateTime.parse(aRaw.toString());
        final bDt = DateTime.parse(bRaw.toString());
        return aDt.compareTo(bDt);
      });

      final now = tz.TZDateTime.now(tz.local);
      var scheduledCount = 0;

      for (final item in items) {
        if (limitToNextN > 0 && scheduledCount >= limitToNextN) break;

        final raw = item['expires_on'];
        if (raw == null) continue;

        final id = item['id'].toString();
        final name = (item['name'] ?? 'Item').toString();
        final expiresOn = DateTime.parse(raw.toString()).toLocal();

        // compute ids
        final base = _baseIdFromItemId(id);
        final reminderId = _reminderIdFromBase(base);
        final expiryId = _expiryIdFromBase(base);

        // cancel both first (idempotent)
        await cancelItemNotification(id);

        // schedule one-day-before (if wanted)
        if (scheduleReminderOnly || scheduleReminderOnly == false) {
          await scheduleOneDayBeforeReminder(
            itemId: id,
            itemName: name,
            expiresOn: expiresOn,
            notificationId: reminderId,
            remindHour: remindHour,
            remindMinute: remindMinute,
            sameTimePreviousDay: false,
          );
        }

        // schedule expiry-day if not reminder-only
        if (!scheduleReminderOnly) {
          await scheduleExpiryNotification(
            itemId: id,
            itemName: name,
            expiresOn: expiresOn,
            notificationId: expiryId,
          );
        }

        // count scheduled reminders (approx)
        final scheduledWhen = _scheduledOneDayBefore(
          expiresOn,
          hour: remindHour,
          minute: remindMinute,
          sameTimePreviousDay: sameTimePreviousDay,
        );
        if (scheduledWhen.isAfter(now)) scheduledCount++;
      }
    } catch (e) {
      print("Supabase error (fetchAndScheduleAll): $e");
    }
  }

  // -------------------------------------------------------
  // REALTIME LISTENER FOR INSERT/UPDATE/DELETE
  // -------------------------------------------------------
  static void subscribeToItemChanges({
    bool scheduleReminderOnly = true,
    int remindHour = 9,
    int remindMinute = 0,
    bool sameTimePreviousDay = false,
  }) {
    final supabase = Supabase.instance.client;

    // prevent multiple subscriptions
    try {
      itemsChannel?.unsubscribe();
    } catch (_) {}
    itemsChannel = supabase.channel('items-ch');

    itemsChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'items',
      callback: (payload) {
        final type = payload.eventType.toString().toUpperCase();
        print("Realtime event: $type");

        if (type.contains('INSERT')) {
          final rec = payload.newRecord;
          final id = rec['id'].toString();
          final name = (rec['name'] ?? 'Item').toString();
          final expiresOn = DateTime.parse(rec['expires_on'].toString()).toLocal();

          final base = _baseIdFromItemId(id);
          final reminderId = _reminderIdFromBase(base);
          final expiryId = _expiryIdFromBase(base);

          // cancel any existing scheduled entries for safety
          cancelItemNotification(id);

          // schedule reminder
          scheduleOneDayBeforeReminder(
            itemId: id,
            itemName: name,
            expiresOn: expiresOn,
            notificationId: reminderId,
            remindHour: remindHour,
            remindMinute: remindMinute,
            sameTimePreviousDay: sameTimePreviousDay,
          );

          // schedule expiry-day if needed
          if (!scheduleReminderOnly) {
            scheduleExpiryNotification(
              itemId: id,
              itemName: name,
              expiresOn: expiresOn,
              notificationId: expiryId,
            );
          }
        }

        if (type.contains('UPDATE')) {
          final rec = payload.newRecord;
          final id = rec['id'].toString();
          final name = (rec['name'] ?? 'Item').toString();
          final expiresOn = DateTime.parse(rec['expires_on'].toString()).toLocal();

          // cancel previous and reschedule
          cancelItemNotification(id);

          final base = _baseIdFromItemId(id);
          final reminderId = _reminderIdFromBase(base);
          final expiryId = _expiryIdFromBase(base);

          scheduleOneDayBeforeReminder(
            itemId: id,
            itemName: name,
            expiresOn: expiresOn,
            notificationId: reminderId,
            remindHour: remindHour,
            remindMinute: remindMinute,
            sameTimePreviousDay: sameTimePreviousDay,
          );

          if (!scheduleReminderOnly) {
            scheduleExpiryNotification(
              itemId: id,
              itemName: name,
              expiresOn: expiresOn,
              notificationId: expiryId,
            );
          }
        }

        if (type.contains('DELETE')) {
          final old = payload.oldRecord;
          final id = old['id'].toString();
          cancelItemNotification(id);
        }
      },
    );

    itemsChannel!.subscribe();
    print("Realtime subscribed to items table.");
  }

  // -------------------------------------------------------
  // UNSUBSCRIBE (call on logout or dispose)
  // -------------------------------------------------------
  static Future<void> unsubscribeFromChanges() async {
    try {
      itemsChannel?.unsubscribe();
      itemsChannel = null;
    } catch (_) {}
  }
}
