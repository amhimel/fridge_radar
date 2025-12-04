// home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fridge_radar/notifications/notification_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/routes.dart';
import '../recipes/suggested_recipes_card.dart';

// ------------------------
// Suggested recipes helpers & widget
// (you can move these to their own file if you prefer)
// ------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _households = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _ensureProfile() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser!.id;
    await supa.from('profiles').upsert({'id': uid});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final supa = Supabase.instance.client;

    try {
      await _ensureProfile();

      final List<dynamic> rows = await supa.rpc('list_my_households').select();
      setState(() {
        _households = rows
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load households: $e')));
    }
  }

  // ---------- UI helpers ----------
  String _initial(String s) {
    final t = s.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

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
        'Dec',
      ];
      return '${m[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return null;
    }
  }

  // Replace the Scaffold body with this code (entire body: ... part)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Households')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_households.isEmpty
                ? _EmptyState(
                    onCreateJoin: () => context.push(AppRoutes.households),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    // Use a SingleChildScrollView with Column so we can show sections
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Households list (shrink-wrapped) ---
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _households.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final h = _households[idx];
                              final name =
                                  (h['name'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? (h['name'] as String)
                                  : 'Unnamed household';
                              final id = h['id'] as String;
                              final createdAt = h['created_at'] as String?;
                              final when = _niceDate(createdAt);

                              return _HouseholdCard(
                                title: name,
                                subtitle:
                                    '${_shortId(id)}${when != null ? "  •  $when" : ""}',
                                leadingText: _initial(name),
                                onTap: () => context.pushNamed(
                                  'households.detail',
                                  pathParameters: {'id': id},
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // --- Section: Suggested recipes header (separate & prominent) ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 4,
                            ),
                            child: Text(
                              'Suggested recipes (expiring items)',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          // --- Suggested recipes card (use your existing widget) ---
                          // wrap in a container to give more breathing space & elevation
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SuggestedRecipesCard(
                                supabase: supa,
                                userId: uid,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // --- Optionally: CTA or footer ---
                          // You can add a small CTA row here if desired.
                        ],
                      ),
                    ),
                  )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.households),
        icon: const Icon(Icons.group_add),
        label: const Text('Create / Join'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// rest of file: _HouseholdCard and _EmptyState unchanged (reuse from your original file)
class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    required this.title,
    required this.subtitle,
    required this.leadingText,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String leadingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Text(
                  leadingText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateJoin});

  final VoidCallback onCreateJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No households yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a new household or join with an invite code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
