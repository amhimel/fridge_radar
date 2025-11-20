import 'dart:async';
import 'dart:developer';
import 'package:go_router/go_router.dart';

import '../../../core/utils/avatar.dart';
import '../../items/presentation/fridge_items_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HouseholdDetailScreen extends StatefulWidget {
  final String householdId;

  const HouseholdDetailScreen({super.key, required this.householdId});

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen> {
  Map<String, dynamic>? _invite;
  RealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    _ensureProfile();
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
        callback: (_) => setState(() {}),
      )
      ..subscribe();
  }

  /// Option A (public bucket): build public URL when rendering.
  String? _resolveAvatarUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http')) return value; // backward-compatible
    final supa = Supabase.instance.client;
    return supa.storage.from('profiles').getPublicUrl(value); // <-- no .data
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

  Future<void> _createFridge(String name) async {
    final supa = Supabase.instance.client;

    try {
      await supa.from('fridges').insert({
        'household_id': widget.householdId,
        'name': name,
      });

      if (!mounted) return;
      setState(() {}); // refresh fridges list

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fridge "$name" created')));
    } catch (e) {
      if (!mounted) return;
      log("Add Fridge Error : $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating fridge: $e')));
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
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add fridge', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Main fridge',
                ),
              ),
              const SizedBox(height: 16),
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
                  child: const Text('Create'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final supa = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: const Text('Household')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: supa
            .from('households')
            .select()
            .eq('id', widget.householdId)
            .single(),
        builder: (context, snapshot) {
          final title = snapshot.data != null
              ? (snapshot.data!['name'] as String)
              : '…';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _createInvite,
                    icon: const Icon(Icons.link),
                    label: const Text('Create invite'),
                  ),
                  const SizedBox(width: 12),
                  if (_invite != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        final code = (_invite?['code'] as String?) ?? '';
                        if (code.isEmpty) return;
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied code: $code')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(
                        (_invite?['code'] as String?) ?? 'Invite code',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),
              Text('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchMembers(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final members = snap.data ?? [];
                  if (members.isEmpty) return const Text('No members yet.');

                  return Column(
                    children: members.map((m) {
                      final name = m['display_name'] as String? ?? 'Someone';
                      final avatarPath = m['avatar_url'] as String?;
                      final avatarUrl = _resolveAvatarUrl(avatarPath);
                      final role = (m['role'] as String).toUpperCase();

                      return ListTile(
                        leading: Avatar(name: name, url: avatarUrl),
                        title: Text(name),
                        subtitle: Text(role),
                      );
                    }).toList(),
                  );
                },
              ),

              //fridge section
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fridges',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _openCreateFridgeSheet,
                    tooltip: 'Add fridge',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchFridges(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final fridges = snap.data ?? [];
                  if (fridges.isEmpty) {
                    return const Text('No fridges yet.');
                  }

                  return Column(
                    children: fridges.map((f) {
                      final id = f['id'] as String;
                      final name = f['name'] as String? ?? 'Fridge';

                      return ListTile(
                        leading: const Icon(Icons.kitchen),
                        title: Text(name),
                        // 👇👇 HERE is where you use onTap + pushNamed
                        onTap: () {
                          context.pushNamed(
                            'fridges.items', // route name from router
                            pathParameters: {'id': id}, // fridge id
                            extra: name, // fridgeName for AppBar
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}


