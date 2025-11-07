// lib/features/auth/presentation/register_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fridge_radar/common/widgets/app_input.dart';
import '../../common/widgets/app_button.dart';
import '../../view_model/providers/auth_providers.dart';
import '../../view_model/providers/register_loading_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  File? _avatarFile;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
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
    final name = nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final confirm = confirmCtrl.text;

    String? emailErr, passErr, confirmErr;
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (email.isEmpty || !re.hasMatch(email)) emailErr = 'Enter a valid email';
    if (pass.isEmpty || pass.length < 6) passErr = 'Password must be at least 6 characters';
    if (confirm.isEmpty) {
      confirmErr = 'Confirm your password';
    } else if (confirm != pass) {confirmErr = 'Passwords do not match';}

    final firstError = [emailErr, passErr, confirmErr].whereType<String>().firstOrNull;
    if (firstError != null) { _showSnack(firstError); return; }

    final loading = ref.read(registerLoadingProvider.notifier);
    loading.state = true;

    try {
      // ⬇️ Use the avatar-enabled register here
      await ref.read(authControllerProvider).register(
        email,
        pass,
        displayName: name,
        avatarFile: _avatarFile, // File? you set via ImagePicker
      );

      // Optional: try to sign in immediately (works if email verification is off)
      try { await ref.read(authControllerProvider).login(email, pass); } catch (_) {}

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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Hello! Register to get started",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Avatar picker
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                          child: _avatarFile == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.edit, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  AppInput(
                    controller: nameCtrl,
                    label: 'Display name (optional)',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  AppInput(
                    controller: emailCtrl,
                    label: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  AppInput(
                    controller: passCtrl,
                    label: 'Enter your password',
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  AppInput(
                    controller: confirmCtrl,
                    label: 'Confirm password',
                    obscureText: true,
                    onSubmitted: (_) => isRegistering ? null : _register(),
                  ),
                  const SizedBox(height: 20),

                  AppButton(
                    label: isRegistering ? 'Registering…' : 'Register',
                    onPressed: isRegistering ? null : _register,
                  ),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isRegistering ? null : () => context.go('/login'),
                    child: const Text('Already have an account? Login Now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
