import 'package:fridge_radar/data/models/custom_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile_model.dart';


final _supa = Supabase.instance.client;
String? get _uid => _supa.auth.currentUser?.id;

class ProfileRepo {
  Future<CustomUserModel?> fetchMyProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    final data = await _supa
        .from('profiles')
        .select('id, display_name, avatar_url')
        .eq('id', uid)
        .single();

    return CustomUserModel.fromMap(data);
  }

  Stream<CustomUserModel?> myProfileStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _supa
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) => rows.isEmpty ? null : CustomUserModel.fromMap(rows.first));
  }

  /// Call this after successful sign-up (or on first login) to ensure a row exists.
  Future<void> upsertMyProfile({
    required String id,
    String? displayName,
    String? avatarUrl,
  }) async {
    await _supa.from('profiles').upsert({
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    });
  }
}
