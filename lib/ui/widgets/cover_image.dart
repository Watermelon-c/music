import 'package:flutter/material.dart';

/// 统一的封面显示：没有图 / 加载失败时退化成音符占位
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.size = 44,
    this.radius = 8,
  });

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFFECE6F5),
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: const Color(0xFF7C4DFF),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      fallback,
            ),
    );
  }
}
