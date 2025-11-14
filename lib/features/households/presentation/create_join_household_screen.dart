import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateJoinHouseholdScreen extends StatefulWidget {
  const CreateJoinHouseholdScreen({super.key});

  @override
  State<CreateJoinHouseholdScreen> createState() => _CreateJoinHouseholdScreenState();
}

class _CreateJoinHouseholdScreenState extends State<CreateJoinHouseholdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Household name required')),
      );
      return;
    }

    setState(() => _loading = true);
    final supa = Supabase.instance.client;
    try {
      final Map<String, dynamic> data = await supa
          .rpc('create_household', params: {'p_name': name})
          .select()
          .single();

      final householdId = data['id'] as String;
      if (!mounted) return;
      context.goNamed('households.detail', pathParameters: {'id': householdId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinWithCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code required')),
      );
      return;
    }

    setState(() => _loading = true);
    final supa = Supabase.instance.client;
    try {
      final Map<String, dynamic> data = await supa
          .rpc('join_household_with_code', params: {'p_code': code})
          .select()
          .single();

      final householdId = data['id'] as String;
      if (!mounted) return;
      context.goNamed('households.detail', pathParameters: {'id': householdId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Households')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          TabBar(
            controller: _tab,
            tabs: const [Tab(text: 'Create'), Tab(text: 'Join')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // Create
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Household name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : _createHousehold,
                          child: busy
                              ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Join
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Invite code',
                          hintText: 'e.g. ABC123',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: !busy,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : _joinWithCode,
                          child: busy
                              ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Join'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
