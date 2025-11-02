import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(Supabase.instance.client);
});

class AuthController {
  AuthController(this._supa);
  final SupabaseClient _supa;

  /// Sign up with email + password.
  /// If email confirmations are ON, this will NOT create a session yet.
  Future<void> register(String email, String password) async {
    try {
      await _supa.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email + password.
  Future<void> login(String email, String password) async {
    try {
      await _supa.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _supa.auth.signOut();
  }
}
