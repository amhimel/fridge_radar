import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/home/home_page.dart';


final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (ctx, st) => const HomePage()),
  ],
);


class FridgeRadarApp extends StatelessWidget {
  const FridgeRadarApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FridgeRadar',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: _router,
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