// lib/features/auth/presentation/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridge_radar/common/widgets/app_input.dart';
import 'package:go_router/go_router.dart';
import '../../common/widgets/app_button.dart';
import '../../view_model/providers/auth_controller.dart';
import '../../view_model/providers/register_loading_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validateEmail(String v) {
    if (v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String v) {
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _register() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final confirm = confirmCtrl.text;

    final emailErr = _validateEmail(email);
    final passErr = _validatePassword(pass);
    final confirmErr = confirm.isEmpty
        ? 'Confirm your password'
        : (confirm != pass ? 'Passwords do not match' : null);

    final firstError = [emailErr, passErr, confirmErr].whereType<String>().firstOrNull;
    if (firstError != null) {
      _showSnack(firstError);
      return;
    }

    final loading = ref.read(registerLoadingProvider.notifier);
    loading.state = true;
    try {
      // 1) Register with ONLY email+password
      await ref.read(authControllerProvider).register(email, pass);

      // 2) Try to login (if email verification is OFF this creates a session)
      try { await ref.read(authControllerProvider).login(email, pass); } catch (_) {}

      // Router will push to /complete-profile if name/avatar missing
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      _showSnack('Registration failed: $e');
    } finally {
      loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegistering = ref.watch(registerLoadingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBDD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 15,top: 10), // keep some margin from edge
          //child: CustomBackButton(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(height: 20,),
                  Text(
                    "Hello! Register to get started",
                    style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20,),
                  AppInput(
                    controller: emailCtrl,
                    label: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: passCtrl,
                    label: 'Enter your  password',
                    //obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    controller: confirmCtrl,
                    label: 'Confirm Password',
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Register',
                    onPressed: isRegistering ? null : _register,
                  ),
                  SizedBox(height: 10,),
                  TextButton(
                    onPressed: isRegistering ? null : () => context.go('/login'),
                    child: const Text('Already have an account? Login Now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}