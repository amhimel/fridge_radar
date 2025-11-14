class CustomUserModel {
  final String displayName;
  final String avatarUrl;

  CustomUserModel({required this.displayName, required this.avatarUrl});

  factory CustomUserModel.fromMap(Map<String, dynamic> m) => CustomUserModel(
    displayName: (m['display_name'] ?? '').toString(),
    avatarUrl: (m['avatar_url'] ?? '').toString(),
  );
}
