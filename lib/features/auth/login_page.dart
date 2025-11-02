import 'package:flutter/material.dart';
import 'package:fridge_radar/common/widgets/app_input.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _doLogin() async {
    final email = _email.text.trim();
    final pass = _password.text;

    if (email.isEmpty) return _showSnack('Email is required');
    if (pass.isEmpty) return _showSnack('Password is required');

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
      if (!mounted) return;
      context.go('/home'); // adjust route if needed
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) return _showSnack('Enter your email first');
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _showSnack('Password reset link sent. Check your email.');
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not send reset email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EBDD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Login Screen',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Welcome back! Glad to see you, Again!",
                      style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    AppInput(controller: _email, label: 'Enter your email'),
                    const SizedBox(height: 30),
                    AppInput(
                      controller: _password,
                      label: 'Enter your password',
                      // If your AppTextField supports onSubmitted, you can do:
                      // onSubmitted: (_) => _doLogin(),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    AppButton(
                      label: 'Log in',
                      onPressed: _loading ? null : _doLogin,
                    ),

                    const SizedBox(height: 50),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Don’t have an account? Register Now'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
