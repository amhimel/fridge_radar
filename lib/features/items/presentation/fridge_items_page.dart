import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/item.dart';
import '../../../view_model/providers/items_repository_provider.dart';
import '../controllers/item_editor_controller.dart';

/// Items for a specific fridge (family provider, no fridgeIdProvider needed)
final fridgeItemsProvider =
FutureProvider.autoDispose.family<List<Item>, String>((ref, fridgeId) async {
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.getItemsForFridge(fridgeId);
});

class FridgeItemsPage extends ConsumerWidget {
  final String fridgeId;
  final String fridgeName;

  const FridgeItemsPage({
    super.key,
    required this.fridgeId,
    required this.fridgeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When create/update/delete finishes, refresh THIS fridge's list
    ref.listen<AsyncValue<void>>(
      itemEditorControllerProvider,
          (prev, next) {
        next.whenOrNull(
          data: (_) => ref.invalidate(fridgeItemsProvider(fridgeId)),
          error: (err, st) {
            log('Item mutation error: $err');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item error: $err')),
              );
            }
          },
        );
      },
    );

    // Read items for this fridge
    final itemsAsync = ref.watch(fridgeItemsProvider(fridgeId));

    return Scaffold(
      appBar: AppBar(title: Text(fridgeName)),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items in this fridge yet'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  item.expiresOn != null
                      ? 'Expires: ${item.expiresOn!.toLocal().toIso8601String().split('T').first}'
                      : 'No expiry date',
                ),
                leading: item.quantity != null
                    ? CircleAvatar(
                  child: Text(
                    item.quantity!.toStringAsFixed(
                      item.quantity! % 1 == 0 ? 0 : 1,
                    ),
                  ),
                )
                    : const CircleAvatar(child: Icon(Icons.kitchen)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await ref
                        .read(itemEditorControllerProvider.notifier)
                        .delete(item.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deleted "${item.name}"')),
                      );
                    }
                  },
                ),
                onTap: () {
                  // Edit existing item
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _ItemFormSheet(
                      fridgeId: fridgeId,
                      initialItem: item,
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text('Error loading items: ${e.toString()}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new item
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _ItemFormSheet(fridgeId: fridgeId),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet form for creating/updating an item
// ---------------------------------------------------------------------------

class _ItemFormSheet extends ConsumerStatefulWidget {
  final String fridgeId;
  final Item? initialItem;

  const _ItemFormSheet({required this.fridgeId, this.initialItem});

  @override
  ConsumerState<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _expiresOn;

  @override
  void initState() {
    super.initState();
    final i = widget.initialItem;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _barcodeCtrl = TextEditingController(text: i?.barcode ?? '');
    _quantityCtrl = TextEditingController(text: i?.quantity?.toString() ?? '');
    _unitCtrl = TextEditingController(text: i?.unit ?? '');
    _notesCtrl = TextEditingController(text: i?.notes ?? '');
    _expiresOn = i?.expiresOn;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _expiresOn ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _expiresOn = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = _quantityCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_quantityCtrl.text.trim());

    final existing = widget.initialItem;

    if (existing == null) {
      // Create
      final newItem = Item(
        id: '', // ignored by repo if you follow our insert code
        fridgeId: widget.fridgeId,
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        quantity: quantity,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        expiresOn: _expiresOn,
        addedBy: null,
        addedAt: null,
        notes:
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref
          .read(itemEditorControllerProvider.notifier)
          .create(newItem);
    } else {
      // Update
      final updated = existing.copyWith(
        name: _nameCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        quantity: quantity,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        expiresOn: _expiresOn,
        notes:
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref
          .read(itemEditorControllerProvider.notifier)
          .update(updated);
    }

    // ✅ error check after mutation
    final state = ref.read(itemEditorControllerProvider);
    if (state.hasError) {
      log('Save item error: ${state.error}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: ${state.error}')),
        );
      }
      return; // error হলে sheet বন্ধ করব না
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;
    final savingState = ref.watch(itemEditorControllerProvider);
    final isSaving = savingState.isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Edit item' : 'Add item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Barcode (optional)',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration:
                      const InputDecoration(labelText: 'Quantity'),
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g. pcs, g, ml)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _expiresOn == null
                          ? 'No expiry date'
                          : 'Expires: ${_expiresOn!.toLocal().toIso8601String().split('T').first}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick date'),
                  ),
                ],
              ),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submit,
                  child: isSaving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child:
                    CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(isEditing ? 'Save changes' : 'Add item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
