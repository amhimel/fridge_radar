// recipe_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeDetailPage extends StatefulWidget {
  final SupabaseClient supabase;
  final String recipeId;

  const RecipeDetailPage({
    required this.supabase,
    required this.recipeId,
    super.key,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool loading = true;
  Map<String, dynamic>? recipe;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  // Replace only the _loadRecipe() method in your RecipeDetailPage State with this:

  Future<void> _loadRecipe() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      dynamic res;
      // try both client shapes: with .execute() and without
      try {
        res = await widget.supabase
            .from('recipes')
            .select('*')
            .eq('id', widget.recipeId)
            .single();
      } catch (e) {
        // fallback if .execute() isn't available on this client version
        debugPrint(
          'select.execute() failed: $e — falling back to direct await',
        );
        res = await widget.supabase
            .from('recipes')
            .select('*')
            .eq('id', widget.recipeId)
            .single();
      }

      // Normalize the response safely:
      Map<String, dynamic>? row;

      // Case A: PostgrestResponse-like object (has .error/.data)
      try {
        final maybeError = (res is Map && res.containsKey('error'))
            ? res['error']
            : ((res).error);
        final maybeData = (res is Map && res.containsKey('data'))
            ? res['data']
            : ((res).data);

        if (maybeError != null) {
          final msg = (maybeError is Map && maybeError.containsKey('message'))
              ? maybeError['message']
              : maybeError.toString();
          setState(() {
            error = 'Failed to load recipe: $msg';
            loading = false;
          });
          return;
        }

        if (maybeData != null) {
          if (maybeData is Map) {
            row = Map<String, dynamic>.from(maybeData);
          } else {
            // sometimes data can be a list with single element
            if (maybeData is List &&
                maybeData.isNotEmpty &&
                maybeData.first is Map) {
              row = Map<String, dynamic>.from(maybeData.first as Map);
            }
          }
        }
      } catch (_) {
        // ignore and fallthrough to other shapes
      }

      // Case B: If res is already a Map row
      if (row == null) {
        if (res is Map<String, dynamic>) {
          row = Map<String, dynamic>.from(res);
        } else if (res is List && res.isNotEmpty && res.first is Map) {
          row = Map<String, dynamic>.from(res.first as Map);
        } else if (res is String) {
          // maybe it's a JSON string
          try {
            final parsed = jsonDecode(res);
            if (parsed is Map) row = Map<String, dynamic>.from(parsed);
          } catch (_) {}
        } else {
          // try dynamic access if API returns object with .data property (but guard it)
          try {
            final dynamic d = res;
            final maybe = d.data;
            if (maybe is Map) row = Map<String, dynamic>.from(maybe);
          } catch (_) {}
        }
      }

      if (row == null) {
        setState(() {
          error =
              'Recipe not found or unexpected response shape: ${res.runtimeType}';
          loading = false;
        });
        debugPrint('DEBUG: unexpected recipe response -> $res');
        return;
      }

      setState(() {
        recipe = row;
        loading = false;
      });
    } catch (e, st) {
      debugPrint('Error loading recipe: $e\n$st');
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Widget _buildIngredients() {
    final ingr = recipe?['ingredients'];
    if (ingr == null) return const Text('No ingredients');

    // ingredients may be jsonb array of strings OR array of objects
    if (ingr is List) {
      // already decoded (unlikely from supabase client), handle generically:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ingr.map<Widget>((e) {
          if (e is String) return Text('• $e');
          if (e is Map) {
            return Text('• ${e['ingredient_text'] ?? e.values.join(' ')}');
          }
          return Text('• ${e.toString()}');
        }).toList(),
      );
    }

    // sometimes supabase returns json as String; try decode
    try {
      final parsed = (ingr is String)
          ? (ingr.isEmpty
                ? []
                : List.from((ingr.startsWith('[') ? (jsonDecode(ingr)) : [])))
          : null;
      if (parsed != null && parsed is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parsed.map<Widget>((e) {
            if (e is String) return Text('• $e');
            if (e is Map) {
              return Text('• ${e['ingredient_text'] ?? e.values.join(' ')}');
            }
            return Text('• ${e.toString()}');
          }).toList(),
        );
      }
    } catch (_) {
      /* ignore parsing error */
    }

    // if jsonb on server, Supabase client often returns it already decoded as List<dynamic>
    try {
      final asList = recipe!['ingredients'] as List<dynamic>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: asList.map<Widget>((e) {
          if (e is String) return Text('• $e');
          if (e is Map) {
            return Text('• ${e['ingredient_text'] ?? e.values.join(' ')}');
          }
          return Text('• ${e.toString()}');
        }).toList(),
      );
    } catch (_) {}

    return const Text('No ingredients available');
  }

  Widget _buildSteps() {
    final steps = recipe?['steps'];
    if (steps == null) return const Text('No steps');

    // steps is text[] ideally; it may come as List or String
    if (steps is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${i + 1}. ${steps[i]}'),
          );
        }),
      );
    }

    if (steps is String) {
      final parts = steps
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(parts.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('${i + 1}. ${parts[i]}'),
          );
        }),
      );
    }

    return const Text('No steps available');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(recipe?['title'] ?? 'Recipe')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null
                ? Center(
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // image (if exists)
                          if (recipe?['image_url'] != null &&
                              (recipe?['image_url'] as String).isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                recipe!['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 250,
                              ),
                            ),
                          const SizedBox(height: 12),

                          Text(
                            recipe?['title'] ?? 'Untitled',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),
                          if (recipe?['source'] != null)
                            Text(
                              'Source: ${recipe!['source']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 18,
                              ),
                            ),

                          const Divider(height: 24),
                          Text('Ingredients', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _buildIngredients(),

                          const Divider(height: 24),

                          Text('Steps', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _buildSteps(),

                          const SizedBox(height: 15),

                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  // you can implement quick use mapping here or navigate back to suggestion to call RPC
                                  // for now we'll pop and let caller handle mapping if needed
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Use items'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
    );
  }
}
