import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Unified AppBar widget for consistent UI across all tabs
class UnifiedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? iconColor;
  final double elevation;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const UnifiedAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.backgroundColor,
    this.titleColor,
    this.iconColor,
    this.elevation = 0,
    this.systemOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Claymorphism theme colors - pastel sáng tươi
    final defaultBackgroundColor = backgroundColor ?? const Color(0xFFF8FAFC);
    final defaultTitleColor = titleColor ?? const Color(0xFF374151);
    final defaultIconColor = iconColor ?? const Color(0xFF6B7280);
    final defaultSystemOverlay =
        systemOverlayStyle ?? SystemUiOverlayStyle.dark;

    return Container(
      decoration: BoxDecoration(
        color: defaultBackgroundColor,
        boxShadow: [
          // Subtle shadow for header
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: AppBar(
        title: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSansSc(
                      color: defaultTitleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.8),
                          offset: const Offset(0.5, 0.5),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    subtitle!,
                    style: GoogleFonts.notoSansSc(
                      color: defaultTitleColor.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.6),
                          offset: const Offset(0.5, 0.5),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Text(
                title,
                style: GoogleFonts.notoSansSc(
                  color: defaultTitleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(0.5, 0.5),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: defaultIconColor),
        systemOverlayStyle: defaultSystemOverlay,
        leading: showBackButton
            ? Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      offset: const Offset(-2, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: defaultIconColor),
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                ),
              )
            : null,
        actions: actions?.map((action) {
          // Wrap action buttons in Claymorphism containers
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: action,
          );
        }).toList(),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Unified body container for consistent styling
class UnifiedBodyContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const UnifiedBodyContainer({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFFAFBFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          // Claymorphism shadows
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(2, 2),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: const Offset(-5, -5),
            blurRadius: 10,
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(0),
      child: child,
    );
  }
}

/// Unified section container for consistent card styling
class UnifiedSectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  const UnifiedSectionContainer({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 24,
    this.backgroundColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: padding ?? const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            boxShadow ??
            [
              // Claymorphism shadows
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                offset: const Offset(3, 3),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                offset: const Offset(-3, -3),
                blurRadius: 10,
              ),
              // Viền trắng glow mờ để nổi bật
              BoxShadow(
                color: Colors.white.withOpacity(0.4),
                offset: const Offset(0, 0),
                blurRadius: 3,
                spreadRadius: 1,
              ),
            ],
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
      ),
      child: child,
    );
  }
}
