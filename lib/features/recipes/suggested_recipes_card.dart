import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fridge_radar/features/recipes/recipe_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Robust helper to call RPC and return normalized List<Map<String,dynamic>>
Future<List<Map<String, dynamic>>> _callRpcList({
  required SupabaseClient supabase,
  required String name,
  Map<String, dynamic>? params,
}) async {
  dynamic rpcRes;
  try {
    // try with .execute() (many supabase versions)
    rpcRes = await supabase.rpc(name, params: params);
  } catch (e) {
    debugPrint('rpc .execute() failed, trying direct await: $e');
    try {
      rpcRes = await supabase.rpc(name, params: params);
    } catch (e2) {
      debugPrint('rpc direct await failed: $e2');
      rethrow;
    }
  }

  // Normalize various shapes
  try {
    // PostgrestResponse-like object with .error/.data
    final dyn = rpcRes;
    final error = (dyn is Map && dyn.containsKey('error'))
        ? dyn['error']
        : (dyn is dynamic ? dyn.error : null);
    final data = (dyn is Map && dyn.containsKey('data'))
        ? dyn['data']
        : (dyn is dynamic ? dyn.data : null);

    if (error != null) {
      final msg = error is Map && error.containsKey('message')
          ? error['message']
          : error.toString();
      throw Exception('RPC $name error: $msg');
    }

    if (data == null) {
      // maybe rpcRes itself is a list or map
      if (rpcRes is List) {
        return List<Map<String, dynamic>>.from(
          rpcRes.map((e) => (e as Map).cast<String, dynamic>()),
        );
      }
      if (rpcRes is Map) {
        return [Map<String, dynamic>.from(rpcRes)];
      }
      return [];
    }

    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((e) => (e as Map).cast<String, dynamic>()),
      );
    } else if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
  } catch (e) {
    debugPrint('normalize rpc result failed: $e');
  }

  // fallback: if rpcRes is List/Map/string
  if (rpcRes is List) {
    return List<Map<String, dynamic>>.from(
      rpcRes.map((e) => (e as Map).cast<String, dynamic>()),
    );
  } else if (rpcRes is Map) {
    return [Map<String, dynamic>.from(rpcRes)];
  } else if (rpcRes is String) {
    try {
      final parsed = jsonDecode(rpcRes);
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(
          parsed.map((e) => (e as Map).cast<String, dynamic>()),
        );
      } else if (parsed is Map) {
        return [Map<String, dynamic>.from(parsed)];
      }
    } catch (_) {}
  }

  return [];
}

Future<List<Map<String, dynamic>>> fetchExpiringFoodItems({
  required SupabaseClient supabase,
  required String userId,
  int lookaheadDays = 5,
}) async {
  try {
    dynamic res;
    try {
      res = await supabase
          .from('items')
          .select('id, name, item_normalized, expires_on, quantity')
          .eq('added_by', userId)
          .eq('notes', 'food')
          .lte(
            'expires_on',
            DateTime.now().add(Duration(days: lookaheadDays)).toIso8601String(),
          )
          .gt('quantity', 0)
          .order('expires_on', ascending: true);
    } catch (e) {
      debugPrint('select .execute() failed: $e');
      res = await supabase
          .from('items')
          .select('id, name, item_normalized, expires_on, quantity')
          .eq('added_by', userId)
          .eq('notes', 'food')
          .lte(
            'expires_on',
            DateTime.now().add(Duration(days: lookaheadDays)).toIso8601String(),
          )
          .gt('quantity', 0)
          .order('expires_on', ascending: true);
    }

    // normalize PostgrestResponse or direct list
    try {
      final err = (res as dynamic).error;
      final data = (res as dynamic).data;
      if (err != null) {
        debugPrint(
          'fetchExpiringFoodItems error: ${err.message ?? err.toString()}',
        );
        return [];
      }
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(
        (data as List).map((e) => (e as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      if (res is List) {
        return List<Map<String, dynamic>>.from(
          res.map((e) => (e as Map).cast<String, dynamic>()),
        );
      } else if (res is Map) {
        return [Map<String, dynamic>.from(res)];
      }
    }
  } catch (e) {
    debugPrint('fetchExpiringFoodItems crashed: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> fetchSuggestedRecipes({
  required SupabaseClient supabase,
  required String userId,
  int lookaheadDays = 5,
}) async {
  try {
    return await _callRpcList(
      supabase: supabase,
      name: 'get_suggested_recipes_by_expiring_items',
      // change if your RPC has different name
      params: {'p_user': userId, 'p_lookahead': lookaheadDays},
    );
  } catch (e) {
    debugPrint('fetchSuggestedRecipes rpc failed: $e');
    return [];
  }
}

Future<void> callUseItems({
  required SupabaseClient supabase,
  required List<Map<String, dynamic>> mappingsJson,
}) async {
  try {
    // try with execute then fallback
    try {
      await supabase.rpc(
        'use_items',
        params: {'p_mappings': jsonEncode(mappingsJson)},
      );
    } catch (_) {
      await supabase.rpc(
        'use_items',
        params: {'p_mappings': jsonEncode(mappingsJson)},
      );
    }
  } catch (e) {
    debugPrint('callUseItems failed: $e');
    rethrow;
  }
}

class SuggestedRecipesCard extends StatefulWidget {
  final SupabaseClient supabase;
  final String userId;
  final int lookaheadDays;

  const SuggestedRecipesCard({
    required this.supabase,
    required this.userId,
    this.lookaheadDays = 5,
    Key? key,
  }) : super(key: key);

  @override
  State<SuggestedRecipesCard> createState() => _SuggestedRecipesCardState();
}

class _SuggestedRecipesCardState extends State<SuggestedRecipesCard> {
  bool loading = true;
  List<Map<String, dynamic>> recipes = [];
  List<Map<String, dynamic>> expiringItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      expiringItems = await fetchExpiringFoodItems(
        supabase: widget.supabase,
        userId: widget.userId,
        lookaheadDays: widget.lookaheadDays,
      );

      if (expiringItems.isEmpty) {
        setState(() {
          recipes = [];
          loading = false;
        });
        return;
      }

      recipes = await fetchSuggestedRecipes(
        supabase: widget.supabase,
        userId: widget.userId,
        lookaheadDays: widget.lookaheadDays,
      );

      setState(() => loading = false);
    } catch (e) {
      debugPrint('SuggestedRecipesCard _load error: $e');
      setState(() {
        loading = false;
        recipes = [];
      });
    }
  }

  // expiry chip helper
  Widget _expiryChip(BuildContext context, String? earliestExpiryIso) {
    if (earliestExpiryIso == null) return const SizedBox.shrink();

    DateTime? dt;
    try {
      dt = DateTime.parse(earliestExpiryIso).toLocal();
    } catch (_) {
      try {
        dt = DateTime.parse(earliestExpiryIso.toString());
      } catch (_) {
        dt = null;
      }
    }
    if (dt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysLeft = dt
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    Color bg;
    String label;

    if (daysLeft < 0) {
      bg = Colors.red;
      label = 'Expired';
    } else if (daysLeft == 0) {
      bg = Colors.red;
      label = 'Today';
    } else if (daysLeft <= 3) {
      bg = Colors.orange;
      label = '${daysLeft}d';
    } else {
      bg = Colors.green;
      label = '${daysLeft}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (expiringItems.isEmpty) return const SizedBox.shrink();

    if (recipes.isEmpty) {
      final names = expiringItems
          .map((e) => e['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title: const Text('Suggested recipes'),
          subtitle: Text('No recipe found for items: $names'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: recipes.map((r) {
              final matched = <String>[];
              if (r['matched_ings'] is List) {
                matched.addAll(
                  (r['matched_ings'] as List).map((e) => e.toString()),
                );
              } else if (r['matched_ings'] is String) {
                matched.add(r['matched_ings'] as String);
              }
              final earliest = r['earliest_expiry']?.toString();

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                title: Text(
                  r['title'] ?? 'Untitled',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Matched: ${matched.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _expiryChip(context, earliest),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (earliest != null)
                      Text(
                        'Earliest: $earliest',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () {
                    // open detail page
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailPage(
                          supabase: widget.supabase,
                          recipeId: (r['recipe_id'] ?? r['id']).toString(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Details'),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(
                        supabase: widget.supabase,
                        recipeId: (r['recipe_id'] ?? r['id']).toString(),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
