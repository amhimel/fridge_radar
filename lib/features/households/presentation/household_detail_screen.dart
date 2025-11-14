import 'dart:async';

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
        .rpc('list_household_members', params: {'p_household_id': widget.householdId})
        .select();
    return rows.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> _createInvite() async {
    final supa = Supabase.instance.client;
    try {
      final Map<String, dynamic> data = await supa
          .rpc('create_household_invite', params: {
        'p_household_id': widget.householdId,
        'p_hours': 48,
      })
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
        future: supa.from('households').select().eq('id', widget.householdId).single(),
        builder: (context, snapshot) {
          final title = snapshot.data != null ? (snapshot.data!['name'] as String) : '…';

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
                      label: Text((_invite?['code'] as String?) ?? 'Invite code'),
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
                      final avatarUrl  = _resolveAvatarUrl(avatarPath);
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
            ],
          );
        },
      ),
    );
  }
}

/// Small, resilient avatar widget (won’t crash on bad URLs; falls back to initials)
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 22});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return SizedBox(
      width: size * 2,
      height: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base: initials (সবসময় থাকবে)
          CircleAvatar(
            radius: size,
            child: Text(initial),
          ),

          // Overlay: network image (লোড হলে ইনিশিয়াল ঢেকে দেয়)
          if (url != null && url!.isNotEmpty)
            ClipOval(
              child: Image.network(
                url!,
                width: size * 2,
                height: size * 2,
                fit: BoxFit.cover,
                // ফেল করলে কিছুই না দেখালে নিচের ইনিশিয়ালই রয়ে যাবে
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                // চাইলে লোডিংয়ে হালকা ফেড/শিমার দিতে পারেন
              ),
            ),
        ],
      ),
    );
  }
}

