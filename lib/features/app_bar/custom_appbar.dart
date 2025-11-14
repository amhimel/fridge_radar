import 'package:flutter/material.dart';

String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

class CustomAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String? profileImageUrl;
  final double height;
  final EdgeInsetsGeometry contentPadding;

  const CustomAppbar({
    super.key,
    required this.name,
    this.profileImageUrl,
    this.height = kToolbarHeight + 20,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(name);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: height,
      title: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            // Name (left)
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Profile avatar (right)
            _Avatar(url: profileImageUrl, initials: initials, size: 40),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String initials;
  final double size;

  const _Avatar({
    required this.url,
    required this.initials,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final placeholder = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF4E63FF),
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
      ),
    );
  }
}
