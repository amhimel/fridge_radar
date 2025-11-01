import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xxs; // 2
  final double xs;  // 4
  final double sm;  // 8
  final double md;  // 16
  final double lg;  // 24
  final double xl;  // 32
  final double xxl; // 48

  const AppSpacing({
    this.xxs = 2,
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
  });

  @override
  AppSpacing copyWith({double? xxs, double? xs, double? sm, double? md, double? lg, double? xl, double? xxl}) =>
      AppSpacing(
        xxs: xxs ?? this.xxs,
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        xxl: xxl ?? this.xxl,
      );

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

@immutable
class AppRadius extends ThemeExtension<AppRadius> {
  final double xs, sm, md, lg, xl;
  const AppRadius({this.xs = 4, this.sm = 8, this.md = 12, this.lg = 16, this.xl = 24});

  @override
  AppRadius copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) =>
      AppRadius(xs: xs ?? this.xs, sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg, xl: xl ?? this.xl);

  @override
  AppRadius lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) return this;
    return AppRadius(
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
    );
  }
}