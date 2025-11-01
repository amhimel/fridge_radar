import 'package:flutter/material.dart';
import 'color_schemes.dart';
import 'tokens.dart';
import 'typography.dart';

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    textTheme: buildTextTheme(Brightness.light),
    scaffoldBackgroundColor: lightColorScheme.background,
    extensions: const [AppSpacing(), AppRadius()],
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: lightColorScheme.inverseSurface),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: lightColorScheme.outline),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    textTheme: buildTextTheme(Brightness.dark),
    scaffoldBackgroundColor: darkColorScheme.background,
    extensions: const [AppSpacing(), AppRadius()],
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkColorScheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: darkColorScheme.inverseSurface),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: darkColorScheme.outline),
    ),
  );
}