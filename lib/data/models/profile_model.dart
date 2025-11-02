class ProfileModel {
  final String id;
  final String email;
  final String? displayName;
  final String? profileImage; // avatar_url

  const ProfileModel({
    required this.id,
    required this.email,
    this.displayName,
    this.profileImage,
  });

  ProfileModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? profileImage,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String?,
      profileImage: map['avatar_url'] as String?,
    );
  }
}