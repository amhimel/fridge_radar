import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../repositories/auth_repository.dart';

/// Repo as a Riverpod provider
final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream of ProfileModel? that reacts to auth changes
final authStateProvider = StreamProvider<ProfileModel?>((ref) {
  return ref.read(authRepoProvider).authStateChanges;
});

/// A light controller that uses the repo (handy for UI)
final authControllerProvider = Provider<AuthController>((ref) {
  final repo = ref.read(authRepoProvider);
  return AuthController(repo);
});

class AuthController {
  AuthController(this._repo);
  final AuthRepository _repo;

  Future<void> register(String email, String password, {String? displayName, File? avatarFile}) async {
    await _repo.register(email: email, password: password, displayName: displayName, avatarFile: avatarFile);
  }

  Future<void> login(String email, String password) => _repo.login(email: email, password: password);

  Future<void> logout() => _repo.logout();
}
