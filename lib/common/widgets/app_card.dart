import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radius = Theme.of(context).extension<AppRadius>()!;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.lg)),
      child: Padding(padding: padding ?? EdgeInsets.all(spacing.md), child: child),
    );
  }
}