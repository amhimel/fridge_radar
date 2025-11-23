import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // 👈 barcode scanner

import '../../../data/models/item.dart';
import '../../../view_model/providers/items_repository_provider.dart';
import '../controllers/item_editor_controller.dart';

/// ─────────────────────────────────────────────────────────────────
/// Expiry helpers (same logic as Household screen; you can later
/// move this into a shared utils file if you like)
/// ─────────────────────────────────────────────────────────────────
enum ItemExpiryStatus { noDate, expired, expiringSoon, ok }

ItemExpiryStatus getExpiryStatus(DateTime? expiresOn) {
  if (expiresOn == null) return ItemExpiryStatus.noDate;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(expiresOn.year, expiresOn.month, expiresOn.day);

  if (date.isBefore(today)) return ItemExpiryStatus.expired;

  final diff = date.difference(today).inDays;
  if (diff >= 0 && diff <= 3) return ItemExpiryStatus.expiringSoon;

  return ItemExpiryStatus.ok;
}

/// কিছু common unit suggestion
const commonUnits = [
  'pieces',
  'grams',
  'kilograms',
  'milliliters',
  'liters',
  'packet',
  'box',
  'jar',
  'bottle',
];

/// Items for a specific fridge (family provider)
final fridgeItemsProvider =
FutureProvider.autoDispose.family<List<Item>, String>((ref, fridgeId) async {
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.getItemsForFridge(fridgeId);
});

/// ─────────────────────────────────────────────────────────────────
/// MAIN SCREEN WITH SEARCH + FILTER
/// ─────────────────────────────────────────────────────────────────
class FridgeItemsPage extends ConsumerStatefulWidget {
  final String fridgeId;
  final String fridgeName;

  const FridgeItemsPage({
    super.key,
    required this.fridgeId,
    required this.fridgeName,
  });

  @override
  ConsumerState<FridgeItemsPage> createState() => _FridgeItemsPageState();
}

class _FridgeItemsPageState extends ConsumerState<FridgeItemsPage> {
  String _searchQuery = '';
  ItemExpiryStatus? _statusFilter; // null = All

  @override
  Widget build(BuildContext context) {
    // When create/update/delete finishes, refresh THIS fridge's list
    ref.listen<AsyncValue<void>>(
      itemEditorControllerProvider,
          (prev, next) {
        next.whenOrNull(
          data: (_) => ref.invalidate(fridgeItemsProvider(widget.fridgeId)),
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
    final itemsAsync = ref.watch(fridgeItemsProvider(widget.fridgeId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.fridgeName)),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items in this fridge yet'));
          }

          // ─────────────────────────────────────────────
          // Sort items by expiry status + date
          // ─────────────────────────────────────────────
          final now = DateTime.now();

          int sortKey(Item i) {
            final status = getExpiryStatus(i.expiresOn);

            int priority;
            switch (status) {
              case ItemExpiryStatus.expired:
                priority = 0;
                break;
              case ItemExpiryStatus.expiringSoon:
                priority = 1;
                break;
              case ItemExpiryStatus.ok:
                priority = 2;
                break;
              case ItemExpiryStatus.noDate:
                priority = 3;
                break;
            }

            final d = i.expiresOn;
            final days = d == null ? 999999 : d.difference(now).inDays;

            // priority আগে, date পরে
            return priority * 1000000 + days;
          }

          final sorted = [...items]..sort((a, b) => sortKey(a).compareTo(sortKey(b)));

          // ─────────────────────────────────────────────
          // Apply search + status filter
          // ─────────────────────────────────────────────
          final q = _searchQuery.trim().toLowerCase();

          final filtered = sorted.where((item) {
            final name = item.name.toLowerCase();
            final matchesSearch = q.isEmpty || name.contains(q);

            final status = getExpiryStatus(item.expiresOn);
            final matchesStatus = _statusFilter == null || _statusFilter == status;

            return matchesSearch && matchesStatus;
          }).toList();

          return Column(
            children: [
              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search items…',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // ── Status filter chips ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusFilterChip(
                        label: 'All',
                        selected: _statusFilter == null,
                        onSelected: () {
                          setState(() => _statusFilter = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: 'Expired',
                        selected: _statusFilter == ItemExpiryStatus.expired,
                        tone: _FilterTone.danger,
                        onSelected: () {
                          setState(() => _statusFilter = ItemExpiryStatus.expired);
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: 'Expiring soon',
                        selected: _statusFilter == ItemExpiryStatus.expiringSoon,
                        tone: _FilterTone.warning,
                        onSelected: () {
                          setState(
                                () => _statusFilter = ItemExpiryStatus.expiringSoon,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: 'Fresh',
                        selected: _statusFilter == ItemExpiryStatus.ok,
                        tone: _FilterTone.good,
                        onSelected: () {
                          setState(() => _statusFilter = ItemExpiryStatus.ok);
                        },
                      ),
                      const SizedBox(width: 8),
                      _StatusFilterChip(
                        label: 'No date',
                        selected: _statusFilter == ItemExpiryStatus.noDate,
                        onSelected: () {
                          setState(() => _statusFilter = ItemExpiryStatus.noDate);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── Item list ──
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                  child: Text('No items match your filters'),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    // Status info
                    final status = getExpiryStatus(item.expiresOn);
                    Color statusBg;
                    Color statusFg;
                    String statusText;

                    switch (status) {
                      case ItemExpiryStatus.expired:
                        statusBg =
                            theme.colorScheme.errorContainer.withOpacity(0.3);
                        statusFg = theme.colorScheme.error;
                        statusText = 'Expired';
                        break;
                      case ItemExpiryStatus.expiringSoon:
                        statusBg =
                            theme.colorScheme.tertiaryContainer.withOpacity(0.3);
                        statusFg = theme.colorScheme.tertiary;
                        statusText = 'Expiring soon';
                        break;
                      case ItemExpiryStatus.ok:
                        statusBg = theme.colorScheme.secondaryContainer
                            .withOpacity(0.3);
                        statusFg = theme.colorScheme.secondary;
                        statusText = 'Fresh';
                        break;
                      case ItemExpiryStatus.noDate:
                        statusBg = theme.colorScheme.surfaceVariant
                            .withOpacity(0.6);
                        statusFg = theme.colorScheme.onSurfaceVariant;
                        statusText = 'No date';
                        break;
                    }

                    // Quantity + unit label
                    String? quantityLabel;
                    if (item.quantity != null) {
                      final qVal = item.quantity!;
                      final isInt = qVal % 1 == 0;
                      final qStr =
                      isInt ? qVal.toStringAsFixed(0) : qVal.toStringAsFixed(1);
                      final unit = (item.unit ?? '').trim();
                      quantityLabel =
                      unit.isEmpty ? qStr : '$qStr ${unit.toLowerCase()}';
                    }

                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(
                              quantityLabel == null ? 0.5 : 0.9,
                            ),
                          ),
                          child: Center(
                            child: quantityLabel != null
                                ? Text(
                              quantityLabel,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme
                                    .colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                                : Icon(
                              Icons.kitchen_outlined,
                              color: theme
                                  .colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.expiresOn != null
                                  ? 'Expires: ${item.expiresOn!.toLocal().toIso8601String().split('T').first}'
                                  : 'No expiry date',
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusFg,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 👇 এখানে UNDO সহ delete লজিক
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            // 1️⃣ আগে লোকালিতে item ধরে রাখি
                            final deletedItem = item;

                            // 2️⃣ আসল delete call
                            await ref
                                .read(
                                itemEditorControllerProvider.notifier)
                                .delete(item.id);

                            if (!context.mounted) return;

                            // 3️⃣ Snackbar + UNDO action
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${item.name}"'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () async {
                                    // 4️⃣ UNDO চাপলে আবার একই আইটেম recreate করি
                                    final recreated = deletedItem.copyWith(
                                      id: '',      // নতুন insert
                                      addedAt: null,
                                    );

                                    await ref
                                        .read(itemEditorControllerProvider
                                        .notifier)
                                        .create(recreated);
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                        onTap: () {
                          // Edit existing item
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _ItemFormSheet(
                              fridgeId: widget.fridgeId,
                              initialItem: item,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text('Error loading items: ${e.toString()}')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Create new item
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => _ItemFormSheet(fridgeId: widget.fridgeId),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
/// Filter chip widget
// ─────────────────────────────────────────────────────────────────

enum _FilterTone { normal, warning, danger, good }

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.tone = _FilterTone.normal,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final _FilterTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color border;
    Color bg;
    Color fg;

    if (!selected) {
      border = theme.colorScheme.outlineVariant;
      bg = Colors.transparent;
      fg = theme.colorScheme.onSurfaceVariant;
    } else {
      switch (tone) {
        case _FilterTone.danger:
          bg = theme.colorScheme.errorContainer;
          fg = theme.colorScheme.onErrorContainer;
          break;
        case _FilterTone.warning:
          bg = theme.colorScheme.tertiaryContainer;
          fg = theme.colorScheme.onTertiaryContainer;
          break;
        case _FilterTone.good:
          bg = theme.colorScheme.secondaryContainer;
          fg = theme.colorScheme.onSecondaryContainer;
          break;
        case _FilterTone.normal:
        default:
          bg = theme.colorScheme.primaryContainer;
          fg = theme.colorScheme.onPrimaryContainer;
      }
      border = Colors.transparent;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
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

  /// 👇 barcode scan using mobile_scanner
  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerPage(),
      ),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcodeCtrl.text = result;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ---------- Quantity parse + validation ----------
    final quantityText = _quantityCtrl.text.trim();
    double? quantity;

    if (quantityText.isEmpty) {
      quantity = null;
    } else {
      quantity = double.tryParse(quantityText);
      if (quantity == null) {
        // invalid number like "abc" / "1..2"
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number for quantity'),
          ),
        );
        return;
      }
      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity must be greater than 0'),
          ),
        );
        return;
      }
    }

    final existing = widget.initialItem;
    final itemName = _nameCtrl.text.trim();

    try {
      if (existing == null) {
        // ---------- Create ----------
        final newItem = Item(
          id: '', // ignored by repo if you follow our insert code
          fridgeId: widget.fridgeId,
          name: itemName,
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          quantity: quantity,
          unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
          expiresOn: _expiresOn,
          addedBy: null,
          addedAt: null,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

        await ref.read(itemEditorControllerProvider.notifier).create(newItem);
      } else {
        // ---------- Update ----------
        final updated = existing.copyWith(
          name: itemName,
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          quantity: quantity,
          unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
          expiresOn: _expiresOn,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

        await ref.read(itemEditorControllerProvider.notifier).update(updated);
      }

      // ✅ controller state check
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

      // ✅ Success → close sheet + show toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? '“$itemName” added' : '“$itemName” updated',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      log('Save item exception: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;
    final savingState = ref.watch(itemEditorControllerProvider);
    final isSaving = savingState.isLoading;
    final theme = Theme.of(context);

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
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
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

              // barcode + scan button
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Barcode (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _scanBarcode,
                    tooltip: 'Scan barcode',
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration:
                      const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
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
              const SizedBox(height: 8),
              // Unit suggestion chips
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: commonUnits.map((u) {
                    return ActionChip(
                      label: Text(u),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _unitCtrl.text = u;
                        });
                      },
                    );
                  }).toList(),
                ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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

/// ────────────────────────────────────────────────────────────────
/// Barcode scanner page using mobile_scanner
/// ────────────────────────────────────────────────────────────────
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isHandled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandled) return;
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isHandled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
