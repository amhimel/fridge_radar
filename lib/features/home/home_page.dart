import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _households = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    // Ensure profile exists (simple upsert)
    final uid = supa.auth.currentUser!.id;
    await supa.from('profiles').upsert({'id': uid}).then((_) {});
    // List households where the user is a member
    final res = await supa
        .from('households')
        .select()
        .order('created_at', ascending: false);
    setState(() => _households = res);
  }

  Future<void> _createHousehold() async {
    final supa = Supabase.instance.client;
    final uid = supa.auth.currentUser!.id;
    final inserted = await supa.from('households').insert({
      'name': 'My Home',
      'owner_id': uid,
    }).select().single();
    // add owner to members
    await supa.from('household_members').insert({
      'household_id': inserted['id'],
      'user_id': uid,
      'role': 'owner',
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Households')),
      body: ListView(
        children: _households
            .map((h) => ListTile(
          title: Text(h['name']),
          subtitle: Text(h['id']),
        ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHousehold,
        child: const Icon(Icons.add),
      ),
    );
  }
}