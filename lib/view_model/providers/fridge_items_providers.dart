import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item.dart';
import '../repositories/items_repository.dart';


// ItemsRepository provider (unchanged)
final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  // if you already defined this somewhere else, keep that version instead
  throw UnimplementedError('itemsRepositoryProvider should be implemented');
});

/// ✅ Fridge items provider as a FAMILY: no more fridgeIdProvider.
final fridgeItemsProvider =
FutureProvider.autoDispose.family<List<Item>, String>((ref, fridgeId) async {
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.getItemsForFridge(fridgeId);
});
