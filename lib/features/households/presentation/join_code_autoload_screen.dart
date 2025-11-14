import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JoinCodeAutoloadScreen extends StatefulWidget {
  final String code;
  const JoinCodeAutoloadScreen({super.key, required this.code});

  @override
  State<JoinCodeAutoloadScreen> createState() => _JoinCodeAutoloadScreenState();
}

class _JoinCodeAutoloadScreenState extends State<JoinCodeAutoloadScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    final supa = Supabase.instance.client;
    try {
      final Map<String, dynamic> data = await supa
          .rpc('join_household_with_code', params: {'p_code': widget.code})
          .select()
          .single();

      final id = data['id'] as String;
      if (!mounted) return;
      context.goNamed('households.detail', pathParameters: {'id': id});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.goNamed('households.createJoin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
