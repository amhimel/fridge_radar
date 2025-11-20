import 'package:flutter/material.dart';

/// Small, resilient avatar widget (won’t crash on bad URLs; falls back to initials)
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 22});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return SizedBox(
      width: size * 2,
      height: size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base: initials (সবসময় থাকবে)
          CircleAvatar(radius: size, child: Text(initial)),

          // Overlay: network image (লোড হলে ইনিশিয়াল ঢেকে দেয়)
          if (url != null && url!.isNotEmpty)
            ClipOval(
              child: Image.network(
                url!,
                width: size * 2,
                height: size * 2,
                fit: BoxFit.cover,
                // ফেল করলে কিছুই না দেখালে নিচের ইনিশিয়ালই রয়ে যাবে
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                // চাইলে লোডিংয়ে হালকা ফেড/শিমার দিতে পারেন
              ),
            ),
        ],
      ),
    );
  }
}