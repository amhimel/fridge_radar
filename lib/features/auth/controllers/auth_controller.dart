// lib/view_model/controllers/auth_controller.dart (উদাহরণ)

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final SupabaseClient _client;

  AuthController(this._client);

  Future<void> register(
      String email,
      String password, {
        String? displayName,
        File? avatarFile,
      }) async {
    // 1) sign up user
    final authRes = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = authRes.user;
    if (user == null) {
      throw Exception('Sign up failed, user is null');
    }

    String? avatarPath; // relative path in bucket, e.g. "userId/123.jpg"

    // 2) যদি ছবি থাকে, আগে storage এ upload করো
    if (avatarFile != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      avatarPath = '${user.id}/$fileName'; // 👈 খুব important

      // bucket নাম: "profiles"
      await _client.storage
          .from('profiles')
          .upload(avatarPath, avatarFile, fileOptions: const FileOptions(upsert: true));
    }

    // 3) profiles টেবিলে row upsert করো
    //    avatar_url এ আমরা শুধু relative path সেভ করব
    await _client.from('profiles').upsert({
      'id': user.id,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
      if (avatarPath != null) 'avatar_url': avatarPath,
    });
  }

  Future<void> login(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }
}
