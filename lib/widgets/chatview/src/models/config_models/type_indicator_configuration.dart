import 'package:flutter/material.dart';

class TypeIndicatorConfiguration {
  const TypeIndicatorConfiguration({
    this.indicatorSize,
    this.indicatorSpacing,
    this.flashingCircleDarkColor,
    this.flashingCircleBrightColor,
    this.typingUserAvatarUrl,
    this.typingUserDisplayName,
  });

  /// Used for giving typing indicator size.
  final double? indicatorSize;

  /// Used for giving spacing between indicator dots.
  final double? indicatorSpacing;

  /// Used to give color of dark circle dots.
  final Color? flashingCircleDarkColor;

  /// Used to give color of light circle dots.
  final Color? flashingCircleBrightColor;

  /// URL of the typing user's avatar.
  final String? typingUserAvatarUrl;

  /// Display name of the typing user. Used to render the initial when
  /// the avatar URL is empty or image loading fails.
  final String? typingUserDisplayName;
}
