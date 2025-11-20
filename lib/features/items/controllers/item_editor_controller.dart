import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/item.dart';
import '../../../view_model/providers/items_repository_provider.dart';
import '../../../view_model/repositories/items_repository.dart';

class ItemEditorController extends StateNotifier<AsyncValue<void>> {
  ItemEditorController(this._repo) : super(const AsyncData(null));

  final ItemsRepository _repo;

  Future<void> create(Item item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.createItem(item);
    });
  }

  Future<void> update(Item item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.updateItem(item);
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteItem(id);
    });
  }
}

final itemEditorControllerProvider =
StateNotifierProvider<ItemEditorController, AsyncValue<void>>((ref) {
  final repo = ref.watch(itemsRepositoryProvider);
  return ItemEditorController(repo);
});
