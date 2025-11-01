import 'package:flutter/material.dart';

TextTheme buildTextTheme(Brightness brightness) {
  final base = Typography.material2021(platform: TargetPlatform.android).black.apply(
    bodyColor: brightness == Brightness.light ? const Color(0xFF0B1211) : const Color(0xFFE5E7EB),
    displayColor: brightness == Brightness.light ? const Color(0xFF0B1211) : const Color(0xFFE5E7EB),
  );

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.3, fontWeight: FontWeight.w600),
  );
}