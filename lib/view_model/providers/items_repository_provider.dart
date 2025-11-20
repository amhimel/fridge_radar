// lib/view_model/providers/items_repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/items_repository.dart';

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final client = Supabase.instance.client;
  return ItemsRepository(client);
});
