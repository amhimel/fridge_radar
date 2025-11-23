// lib/features/households/presentation/household_detail_screen.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/avatar.dart';
import '../../items/presentation/fridge_items_page.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Expiry helpers (move to shared utils if you want)
/// ─────────────────────────────────────────────────────────────────────────
enum ItemExpiryStatus { noDate, expired, expiringSoon, ok }

ItemExpiryStatus getExpiryStatus(DateTime? expiresOn) {
  if (expiresOn == null) return ItemExpiryStatus.noDate;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(expiresOn.year, expiresOn.month, expiresOn.day);

  if (date.isBefore(today)) return ItemExpiryStatus.expired;

  final diff = date.difference(today).inDays;
  if (diff >= 0 && diff <= 3) return ItemExpiryStatus.expiringSoon;

  return ItemExpiryStatus.ok;
}

class HouseholdItemsSummary {
  final int total;
  final int expired;
  final int expiringSoon;

  const HouseholdItemsSummary({
    required this.total,
    required this.expired,
    required this.expiringSoon,
  });

  const HouseholdItemsSummary.empty()
      : total = 0,
        expired = 0,
        expiringSoon = 0;
}

/// সব ডেটা এক জায়গায়
class _HouseholdPageData {
  final Map<String, dynamic> household;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> fridges;
  final HouseholdItemsSummary summary;

  _HouseholdPageData({
    required this.household,
    required this.members,
    required this.fridges,
    required this.summary,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// Screen
/// ─────────────────────────────────────────────────────────────────────────
class HouseholdDetailScreen extends StatefulWidget {
  final String householdId;

  const HouseholdDetailScreen({super.key, required this.householdId});

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen> {
  Map<String, dynamic>? _invite;
  RealtimeChannel? _realtime;

  late Future<_HouseholdPageData> _future; // ✅ single future

  @override
  void initState() {
    super.initState();
    _ensureProfile();
    _future = _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtime?.unsubscribe();
    super.dispose();
  }

  Future<void> _ensureProfile() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id;
    if (uid != null) {
      unawaited(supa.from('profiles').upsert({'id': uid}));
    }
  }

  void _subscribeRealtime() {
    final supa = Supabase.instance.client;
    _realtime = supa.channel('public:household_members:${widget.householdId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'household_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: widget.householdId,
        ),
        callback: (_) => _reload(), // 🔁 reload everything when members change
      )
      ..subscribe();
  }

  void _reload() {
    setState(() {
      _future = _loadAll();
    });
  }

  String? _resolveAvatarUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http')) return value;
    final supa = Supabase.instance.client;
    return supa.storage.from('profiles').getPublicUrl(value);
  }

  Future<List<Map<String, dynamic>>> _fetchMembers() async {
    final supa = Supabase.instance.client;
    final List<dynamic> rows = await supa
        .rpc(
      'list_household_members',
      params: {'p_household_id': widget.householdId},
    )
        .select();
    return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchFridges() async {
    final supa = Supabase.instance.client;
    final List<dynamic> rows = await supa
        .from('fridges')
        .select()
        .eq('household_id', widget.householdId);
    return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<HouseholdItemsSummary> _calcItemsSummary(
      List<Map<String, dynamic>> fridges,
      ) async {
    final supa = Supabase.instance.client;

    final fridgeIds = fridges.map((f) => f['id'] as String).toList();
    if (fridgeIds.isEmpty) return const HouseholdItemsSummary.empty();

    final List<dynamic> rows = await supa
        .from('items')
        .select('expires_on')
        .inFilter('fridge_id', fridgeIds);

    int total = rows.length;
    int expired = 0;
    int expiringSoon = 0;

    for (final raw in rows) {
      final map = (raw as Map).cast<String, dynamic>();
      final expiresStr = map['expires_on'] as String?;
      DateTime? expiresOn;
      if (expiresStr != null) {
        try {
          expiresOn = DateTime.parse(expiresStr);
        } catch (_) {}
      }

      final status = getExpiryStatus(expiresOn);
      switch (status) {
        case ItemExpiryStatus.expired:
          expired++;
          break;
        case ItemExpiryStatus.expiringSoon:
          expiringSoon++;
          break;
        default:
          break;
      }
    }

    return HouseholdItemsSummary(
      total: total,
      expired: expired,
      expiringSoon: expiringSoon,
    );
  }

  /// সব কিছু এক ফাংশনে লোড
  Future<_HouseholdPageData> _loadAll() async {
    final supa = Supabase.instance.client;

    final household = await supa
        .from('households')
        .select()
        .eq('id', widget.householdId)
        .single();

    final members = await _fetchMembers();
    final fridges = await _fetchFridges();
    final summary = await _calcItemsSummary(fridges);

    return _HouseholdPageData(
      household: (household as Map).cast<String, dynamic>(),
      members: members,
      fridges: fridges,
      summary: summary,
    );
  }

  Future<void> _createFridge(String name) async {
    final supa = Supabase.instance.client;

    try {
      await supa.from('fridges').insert({
        'household_id': widget.householdId,
        'name': name,
      });

      if (!mounted) return;
      _reload(); // নতুন ফ্রিজ → data reload
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fridge "$name" created')),
      );
    } catch (e) {
      if (!mounted) return;
      log("Add Fridge Error : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating fridge: $e')),
      );
    }
  }

  void _openCreateFridgeSheet() {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New fridge', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Main fridge',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Name is required')),
                      );
                      return;
                    }

                    _createFridge(name);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Create fridge'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createInvite() async {
    final supa = Supabase.instance.client;
    try {
      final Map<String, dynamic> data = await supa
          .rpc(
        'create_household_invite',
        params: {'p_household_id': widget.householdId, 'p_hours': 48},
      )
          .select()
          .single();
      setState(() => _invite = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  String? _niceDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
        centerTitle: false,
      ),
      body: FutureBuilder<_HouseholdPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // ✅ একটাই loader পুরো পেইজের জন্য
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data'));
          }

          final data = snapshot.data!;
          final house = data.household;
          final title =
          (house['name'] as String?)?.trim().isNotEmpty == true
              ? house['name'] as String
              : 'Household';
          final createdLabel = _niceDate(house['created_at'] as String?);
          final members = data.members;
          final fridges = data.fridges;
          final summary = data.summary;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // ── Overview card (name + stats + invite) ──
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   title,
                        //   style: theme.textTheme.titleLarge
                        //       ?.copyWith(fontWeight: FontWeight.w600),
                        // ),
                        // if (createdLabel != null) ...[
                        //   const SizedBox(height: 4),
                        //   Text(
                        //     'Created $createdLabel',
                        //     style: theme.textTheme.bodySmall?.copyWith(
                        //       color: theme.colorScheme.onSurfaceVariant,
                        //     ),
                        //   ),
                        // ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _StatChip(
                              label: '${summary.total} items',
                              icon: Icons.inventory_2_outlined,
                              tone: _StatChipTone.neutral,
                            ),
                            if (summary.expired > 0)
                              _StatChip(
                                label: '${summary.expired} expired',
                                icon: Icons.warning_amber_outlined,
                                tone: _StatChipTone.danger,
                              ),
                            if (summary.expiringSoon > 0)
                              _StatChip(
                                label:
                                '${summary.expiringSoon} expiring soon',
                                icon: Icons.schedule_outlined,
                                tone: _StatChipTone.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _createInvite,
                              icon: const Icon(Icons.link),
                              label: const Text('Create invite'),
                            ),
                            const SizedBox(width: 8),
                            if (_invite != null)
                              TextButton.icon(
                                onPressed: () {
                                  final code =
                                      (_invite?['code'] as String?) ?? '';
                                  if (code.isEmpty) return;
                                  Clipboard.setData(
                                    ClipboardData(text: code),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied code: $code'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: Text(
                                  (_invite?['code'] as String?) ??
                                      'Copy invite code',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Members card ──
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(title: 'Members'),
                        const SizedBox(height: 8),
                        if (members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No members yet.'),
                          )
                        else
                          Column(
                            children: [
                              for (final m in members) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Avatar(
                                    name: m['display_name'] as String? ??
                                        'Someone',
                                    url: _resolveAvatarUrl(
                                      m['avatar_url'] as String?,
                                    ),
                                  ),
                                  title: Text(
                                    m['display_name'] as String? ?? 'Someone',
                                  ),
                                  subtitle: Text(
                                    (m['role'] as String? ?? '')
                                        .toUpperCase(),
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (m != members.last)
                                  const Divider(height: 8),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Fridges card ──
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _SectionHeader(title: 'Fridges'),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add),
                              visualDensity: VisualDensity.compact,
                              onPressed: _openCreateFridgeSheet,
                              tooltip: 'Add fridge',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (fridges.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No fridges yet.'),
                          )
                        else
                          Column(
                            children: [
                              for (final f in fridges) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: theme.colorScheme.primaryContainer
                                          .withOpacity(0.7),
                                    ),
                                    child: Icon(
                                      Icons.kitchen_outlined,
                                      color:
                                      theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  title: Text(
                                    f['name'] as String? ?? 'Fridge',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    final id = f['id'] as String;
                                    final name =
                                        f['name'] as String? ?? 'Fridge';
                                    context.pushNamed(
                                      'fridges.items',
                                      pathParameters: {'id': id},
                                      extra: name,
                                    );
                                  },
                                ),
                                if (f != fridges.last)
                                  const Divider(height: 12),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Small UI helpers
/// ─────────────────────────────────────────────────────────────────────────

enum _StatChipTone { neutral, warning, danger }

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    this.tone = _StatChipTone.neutral,
  });

  final String label;
  final IconData icon;
  final _StatChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg;
    Color fg;

    switch (tone) {
      case _StatChipTone.warning:
        bg = theme.colorScheme.tertiaryContainer.withOpacity(0.25);
        fg = theme.colorScheme.tertiary;
        break;
      case _StatChipTone.danger:
        bg = theme.colorScheme.errorContainer.withOpacity(0.3);
        fg = theme.colorScheme.error;
        break;
      case _StatChipTone.neutral:
      default:
        bg = theme.colorScheme.surfaceVariant.withOpacity(0.6);
        fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style:
      theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
