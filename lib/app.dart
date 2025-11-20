import 'package:flutter/material.dart';
import 'package:fridge_radar/core/utils/routes.dart';
import 'core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';




class FridgeRadarApp extends ConsumerStatefulWidget {
  const FridgeRadarApp({super.key});

  @override
  ConsumerState<FridgeRadarApp> createState() => _FridgeRadarAppState();
}

class _FridgeRadarAppState extends ConsumerState<FridgeRadarApp> {
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