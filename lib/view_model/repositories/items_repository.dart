// lib/features/items/repositories/items_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/item.dart';

class ItemsRepository {
  final SupabaseClient _client;

  ItemsRepository(this._client);

  Future<List<Item>> getItemsForFridge(String fridgeId) async {
    final res = await _client
        .from('items')
        .select('*')
        .eq('fridge_id', fridgeId)
        .order('expires_on', ascending: true);

    return (res as List)
        .map((row) => Item.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Item> createItem(Item item) async {
    final currentUserId = _client.auth.currentUser?.id;

    final insertData = <String, dynamic>{
      'fridge_id': item.fridgeId,
      'name': item.name,
      'barcode': item.barcode,
      'quantity': item.quantity,
      'unit': item.unit,
      'expires_on': item.expiresOn?.toIso8601String(),
      'notes': item.notes,
      'added_by': item.addedBy ?? currentUserId,
      // 'added_at' DB default now()
    };

    final res = await _client
        .from('items')
        .insert(insertData)
        .select()
        .single();

    return Item.fromMap(res as Map<String, dynamic>);
  }

  Future<Item> updateItem(Item item) async {
    final updateData = <String, dynamic>{
      'fridge_id': item.fridgeId,
      'name': item.name,
      'barcode': item.barcode,
      'quantity': item.quantity,
      'unit': item.unit,
      'expires_on': item.expiresOn?.toIso8601String(),
      'notes': item.notes,
      'added_by': item.addedBy,
      // 'added_at' অপরিবর্তিত থাকবে
    };

    final res = await _client
        .from('items')
        .update(updateData)
        .eq('id', item.id)
        .select()
        .single();

    return Item.fromMap(res as Map<String, dynamic>);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('items').delete().eq('id', id);
  }
}
