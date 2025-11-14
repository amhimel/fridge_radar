import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fridge_radar/data/models/custom_user_model.dart';
import '../../data/models/profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepoProvider = Provider<ProfileRepo>((ref) => ProfileRepo());

final profileFutureProvider = FutureProvider<CustomUserModel?>((ref) async {
  final repo = ref.watch(profileRepoProvider);
  return repo.fetchMyProfile();
});

final profileStreamProvider = StreamProvider<CustomUserModel?>((ref) {
  final repo = ref.watch(profileRepoProvider);
  return repo.myProfileStream();
});
