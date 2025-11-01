import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  const AppButton({super.key, required this.label, this.onPressed, this.icon, this.variant = ButtonVariant.filled});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon!, size: 18), SizedBox(width: spacing.xs)],
        Text(label),
      ],
    );

    switch (variant) {
      case ButtonVariant.filled:
        return FilledButton(onPressed: onPressed, child: child);
      case ButtonVariant.tonal:
        return FilledButton.tonal(onPressed: onPressed, child: child);
      case ButtonVariant.outlined:
        return OutlinedButton(onPressed: onPressed, child: child);
      case ButtonVariant.text:
        return TextButton(onPressed: onPressed, child: child);
    }
  }
}

enum ButtonVariant { filled, tonal, outlined, text }