// features/auth/repositories/auth_repository.dart
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile_model.dart';


class AuthRepository {
  final _sb = Supabase.instance.client;

  /// Mobile deep link you added in Supabase → Auth → URL Configuration → Additional Redirect URLs
  static const kEmailRedirect = 'io.fridge_rader.app//auth-callback';

  /// EXACT storage bucket id (rename if your bucket is 'avators', etc.)
  static const kAvatarBucket = 'profiles';

  // ───────────────────────────────── AUTH STATE STREAM ─────────────────────────
  /// Emits:
  /// - null when signed out
  /// - ProfileModel (fresh from `profiles`) when signed in
  Stream<ProfileModel?> get authStateChanges async* {
    // Emit current snapshot immediately
    yield await _currentUser();

    // Then react to auth changes
    await for (final _ in _sb.auth.onAuthStateChange) {
      yield await _currentUser();
    }
  }

  Future<ProfileModel?> _currentUser() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;

    final data = await _sb
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle(); // safe even if row doesn't exist yet

    if (data == null) {
      // Minimal fallback so UI has something until we create the row
      return ProfileModel(id: user.id, email: user.email ?? '');
    }
    return ProfileModel.fromMap(data);
  }

  // ───────────────────────────────── REGISTER ──────────────────────────────────
  Future<ProfileModel> register({
    required String email,
    required String password,
    String? displayName,
    File? avatarFile,
  }) async {
    // Save display name in user metadata + pass deep-link for email verify
    final signRes = await _sb.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: kEmailRedirect,
    );
    final user = signRes.user;
    if (user == null) throw AuthException('Sign up failed');

    // If email confirmation is ON, there is no session yet → skip writes now
    final hasSession = _sb.auth.currentSession != null;

    if (hasSession) {
      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatarBinary(user.id, avatarFile);
      }

      await _sb
          .from('profiles')
          .upsert({
            'id': user.id,
            //'email': email,
            'display_name': displayName,
            'avatar_url': avatarUrl,
          }, onConflict: 'id')
          .select()
          .single();
    }

    // Return minimal; full row will exist after first real login
    return ProfileModel(id: user.id, email: email, displayName: displayName);
  }

  // ───────────────────────────────── LOGIN ─────────────────────────────────────
  Future<ProfileModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _sb.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user!;
    // Ensure a minimal row exists (id/email)
    await _sb
        .from('profiles')
        .upsert({'id': user.id,
      //'email': user.email
    }, onConflict: 'id')
        .select()
        .single();

    final finalRow = await _sb
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    return ProfileModel.fromMap(finalRow);
  }

  // ───────────────────────────────── UPDATE PROFILE ────────────────────────────
  Future<ProfileModel> updateProfile({
    String? displayName,
    File? avatarFile,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) throw AuthException('Not logged in');

    final updateMap = <String, dynamic>{};

    if (avatarFile != null) {
      final avatarUrl = await _uploadAvatarBinary(user.id, avatarFile);
      updateMap['avatar_url'] = avatarUrl;
    }
    if (displayName != null) updateMap['display_name'] = displayName;

    if (updateMap.isEmpty) {
      final current = await _sb
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return ProfileModel.fromMap(current);
    }

    final updated = await _sb
        .from('profiles')
        .update(updateMap)
        .eq('id', user.id)
        .select()
        .single();
    return ProfileModel.fromMap(updated);
  }

  // ───────────────────────────────── LOGOUT / SNAPSHOT ────────────────────────
  Future<void> logout() async => _sb.auth.signOut();

  ProfileModel? get currentUserSync {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    return ProfileModel(id: user.id, email: user.email ?? '');
  }

  void dispose() {}

  // ───────────────────────────────── HELPERS ───────────────────────────────────
  String _avatarKey(String uid, String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$uid/$ts.$ext'; // key INSIDE the bucket (no 'avatars/' prefix)
  }

  Future<String> _uploadAvatarBinary(String uid, File file) async {
    final key = _avatarKey(uid, file.path);
    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';

    await _sb.storage
        .from(kAvatarBucket)
        .uploadBinary(
      key,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: mime,
      ),
    );

    // আগে: return public URL
    // এখন: শুধু key (relative path) রিটার্ন করব
    return key;   // উদাহরণ: "6c4f8d93-.../1700000000000.jpg"
  }

}
