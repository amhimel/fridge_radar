import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:fridge_radar/core/utils/routes.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FridgeRadarApp extends ConsumerStatefulWidget {
  const FridgeRadarApp({super.key});

  @override
  ConsumerState<FridgeRadarApp> createState() => _FridgeRadarAppState();
}

class _FridgeRadarAppState extends ConsumerState<FridgeRadarApp> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initialization();
  }
  void initialization() async {
    // Any initialization code can go here
    // remove splash after first frame
    print("Pausing......");
    Future.delayed( const Duration(seconds: 3));
    print("Unpausing......");
    FlutterNativeSplash.remove();
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FridgeRadar',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('bn')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
