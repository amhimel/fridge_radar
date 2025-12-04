import 'dart:developer';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fridge_radar/core/utils/api_constant.dart';
import 'package:fridge_radar/notifications/notification_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // lock orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: "assets/.env");

  // initialize Supabase
  await Supabase.initialize(
    url: ApiConstant.supabaseUrl,
    anonKey: ApiConstant.supabaseANON_KEY,
  );

  // timezone init (use distinct prefix)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

  // initialize notifications and wait for permissions before scheduling
  await NotificationHelper.initialize();
  await NotificationHelper.requestPermissions();

  // fetch items and schedule (await and catch errors)
  try {
    await NotificationHelper.fetchAndScheduleAll(
      scheduleReminderOnly: true,
      remindHour: 9,
      remindMinute: 0,
    );
  } catch (e, st) {
    // handle or log — won't crash the app
    log('Error scheduling initial notifications: $e\n$st');
  }
  //start realtime subscription here
  // Start realtime listener with same mode
  NotificationHelper.subscribeToItemChanges(
    scheduleReminderOnly: true,
    remindHour: 9,
    remindMinute: 0,
  );
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const ProviderScope(child: FridgeRadarApp()));
}
