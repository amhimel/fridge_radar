// lib/features/fridges/presentation/fridge_summary_badges.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../view_model/providers/items_repository_provider.dart';

/// Summary model: একটা fridge-এর items নিয়ে টোটাল হিসাব
class FridgeItemsSummary {
  final int total;
  final int expired;
  final int expiringSoon;
  final int ok;
  final int noDate;

  const FridgeItemsSummary({
    required this.total,
    required this.expired,
    required this.expiringSoon,
    required this.ok,
    required this.noDate,
  });
}

/// এই provider fridgeId নিয়ে ওই fridge-এর items read করে summary বের করে
final fridgeItemsSummaryProvider =
FutureProvider.family<FridgeItemsSummary, String>((ref, fridgeId) async {
  final repo = ref.watch(itemsRepositoryProvider);
  final items = await repo.getItemsForFridge(fridgeId);

  int expired = 0;
  int expiringSoon = 0;
  int ok = 0;
  int noDate = 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final item in items) {
    final ex = item.expiresOn;
    if (ex == null) {
      noDate++;
      continue;
    }

    final date = DateTime(ex.year, ex.month, ex.day);

    if (date.isBefore(today)) {
      expired++;
    } else {
      final diff = date.difference(today).inDays;
      if (diff >= 0 && diff <= 3) {
        expiringSoon++;
      } else {
        ok++;
      }
    }
  }

  return FridgeItemsSummary(
    total: items.length,
    expired: expired,
    expiringSoon: expiringSoon,
    ok: ok,
    noDate: noDate,
  );
});

/// HomePage-এর fridge card-এ use করার জন্য ready-made widget
class FridgeSummaryBadges extends ConsumerWidget {
  final String fridgeId;

  const FridgeSummaryBadges({
    super.key,
    required this.fridgeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(fridgeItemsSummaryProvider(fridgeId));

    return summaryAsync.when(
      loading: () => const SizedBox(
        height: 16,
        child: LinearProgressIndicator(),
      ),
      error: (e, st) => const Text(
        'Items unavailable',
        style: TextStyle(fontSize: 12),
      ),
      data: (s) {
        // কিছুই না থাকলে "No items" দেখাই
        if (s.total == 0) {
          return _badge(
            text: 'No items',
            color: Colors.grey.withOpacity(0.1),
            textColor: Colors.grey,
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (s.expired > 0)
              _badge(
                text: '${s.expired} expired',
                color: Colors.red.withOpacity(0.1),
                textColor: Colors.red,
              ),
            if (s.expiringSoon > 0)
              _badge(
                text: '${s.expiringSoon} expiring soon',
                color: Colors.orange.withOpacity(0.1),
                textColor: Colors.orange,
              ),
            if (s.ok > 0)
              _badge(
                text: '${s.ok} ok',
                color: Colors.green.withOpacity(0.1),
                textColor: Colors.green,
              ),
          ],
        );
      },
    );
  }

  Widget _badge({
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
