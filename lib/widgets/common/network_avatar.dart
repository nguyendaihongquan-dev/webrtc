import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable avatar widget that
/// - loads avatar via CachedNetworkImage
/// - shows a gradient + initial placeholder while loading or on error
/// - renders as a circle by default
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.size,
    this.border,
    this.cacheKey,
  });

  final String imageUrl;
  final String displayName;
  final double size;
  final BoxBorder? border;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    final String initial =
        (displayName.isNotEmpty ? displayName.characters.first : '?')
            .toUpperCase();

    Widget buildInitial() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(2, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            initial,
            style: GoogleFonts.notoSansSc(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) return buildInitial();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: border),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheKey: cacheKey ?? imageUrl,
        useOldImageOnUrlChange: true,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 100),
        fit: BoxFit.cover,
        placeholder: (context, url) => buildInitial(),
        errorWidget: (context, url, error) => buildInitial(),
      ),
    );
  }
}
