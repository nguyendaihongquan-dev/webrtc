import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

class ImageMessageConfiguration {
  const ImageMessageConfiguration({
    this.hideShareIcon = false,
    this.shareIconConfig,
    this.onTap,
    this.height,
    this.width,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  /// Provides configuration of share button while image message is appeared.
  final ShareIconConfiguration? shareIconConfig;

  /// Hide share icon in image view.
  final bool hideShareIcon;

  /// Provides callback when user taps on image message.
  final ValueSetter<Message>? onTap;

  /// Used for giving height of image message.
  final double? height;

  /// Used for giving width of image message.
  final double? width;

  /// Used for giving padding of image message.
  final EdgeInsetsGeometry? padding;

  /// Used for giving margin of image message.
  final EdgeInsetsGeometry? margin;

  /// Used for giving border radius of image message.
  final BorderRadius? borderRadius;
}

class ShareIconConfiguration {
  ShareIconConfiguration({
    this.onPressed,
    this.onMessagePressed,
    this.icon,
    this.defaultIconBackgroundColor,
    this.padding,
    this.margin,
    this.defaultIconColor,
  });

  /// Provides callback when user press on share button.
  final ValueSetter<String>? onPressed; // Returns imageURL

  /// Provides callback when user press on share button with Message object.
  /// This takes priority over onPressed if both are provided.
  final ValueSetter<Message>? onMessagePressed;

  /// Provides ability to add custom share icon.
  final Widget? icon;

  /// Used to give share icon background color.
  final Color? defaultIconBackgroundColor;

  /// Used to give share icon padding.
  final EdgeInsetsGeometry? padding;

  /// Used to give share icon margin.
  final EdgeInsetsGeometry? margin;

  /// Used to give share icon color.
  final Color? defaultIconColor;
}
