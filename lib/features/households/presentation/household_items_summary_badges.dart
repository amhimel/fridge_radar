// lib/features/households/presentation/household_items_summary_badges.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Household level items summary
class HouseholdItemsSummary {
  final int total;
  final int expired;
  final int expiringSoon;
  final int ok;
  final int noDate;

  const HouseholdItemsSummary({
    required this.total,
    required this.expired,
    required this.expiringSoon,
    required this.ok,
    required this.noDate,
  });
}

/// সব ফ্রিজ + সব item টেনে summary বানায়
final householdItemsSummaryProvider =
FutureProvider.family<HouseholdItemsSummary, String>((ref, householdId) async {
  final supa = Supabase.instance.client;

  // 1) এই household-এর সব ফ্রিজ আইডি আনি
  final List<dynamic> fridgeRows = await supa
      .from('fridges')
      .select('id')
      .eq('household_id', householdId);

  final fridgeIds = fridgeRows
      .map((row) => (row as Map)['id'] as String)
      .toList();

  if (fridgeIds.isEmpty) {
    return const HouseholdItemsSummary(
      total: 0,
      expired: 0,
      expiringSoon: 0,
      ok: 0,
      noDate: 0,
    );
  }

  // 🔹 Supabase `filter('col', 'in', '("id1","id2")')` ফরম্যাট চায়
  final inValue = '(${fridgeIds.map((id) => '"$id"').join(',')})';

  // 2) সব item টেনে আনি (expires_on দরকার)
  final List<dynamic> itemRows = await supa
      .from('items')
      .select('expires_on')
      .filter('fridge_id', 'in', inValue);

  int expired = 0;
  int expiringSoon = 0;
  int ok = 0;
  int noDate = 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final raw in itemRows) {
    final row = raw as Map<String, dynamic>;
    final value = row['expires_on'];

    if (value == null) {
      noDate++;
      continue;
    }

    DateTime ex;
    if (value is String) {
      ex = DateTime.parse(value).toLocal();
    } else if (value is DateTime) {
      ex = value.toLocal();
    } else {
      // অদ্ভুত কিছু হলে noDate ধরলাম
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

  final total = itemRows.length;

  return HouseholdItemsSummary(
    total: total,
    expired: expired,
    expiringSoon: expiringSoon,
    ok: ok,
    noDate: noDate,
  );
});

/// UI widget – Household title-এর নিচে ব্যবহার করব
class HouseholdSummaryBadges extends ConsumerWidget {
  final String householdId;

  const HouseholdSummaryBadges({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSummary = ref.watch(householdItemsSummaryProvider(householdId));

    return asyncSummary.when(
      loading: () => const SizedBox(height: 4),
      error: (e, st) => const SizedBox.shrink(),
      data: (s) {
        if (s.total == 0) {
          return const Text(
            'No items in this household yet',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _badge(
              text: '${s.total} items',
              color: Colors.blueGrey.withOpacity(0.08),
              textColor: Colors.blueGrey,
            ),
            if (s.expired > 0)
              _badge(
                text: '${s.expired} expired',
                color: Colors.red.withOpacity(0.08),
                textColor: Colors.red,
              ),
            if (s.expiringSoon > 0)
              _badge(
                text: '${s.expiringSoon} expiring soon',
                color: Colors.orange.withOpacity(0.08),
                textColor: Colors.orange,
              ),
            if (s.ok > 0)
              _badge(
                text: '${s.ok} ok',
                color: Colors.green.withOpacity(0.08),
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
