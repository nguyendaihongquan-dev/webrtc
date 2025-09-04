import 'package:flutter/material.dart';

import '../../values/typedefs.dart';

class MessageReactionConfiguration {
  const MessageReactionConfiguration({
    this.reactionsBottomSheetConfig,
    this.reactionCountTextStyle,
    this.reactedUserCountTextStyle,
    this.reactionSize,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.profileCircleRadius,
    this.profileCirclePadding,
  });

  /// Used for giving size of reaction on message.
  final double? reactionSize;

  /// Used for giving margin of reaction on message.
  final EdgeInsetsGeometry? margin;

  /// Used for giving padding of reaction on message.
  final EdgeInsetsGeometry? padding;

  /// Used for giving background colour to reaction on message.
  final Color? backgroundColor;

  /// Used for giving border radius of reaction on message.
  final BorderRadiusGeometry? borderRadius;

  /// Used for giving colour of border to reaction on message.
  final Color? borderColor;

  /// Used for giving border width of reaction on message.
  final double? borderWidth;

  /// Used for giving text style reacted user's name of reaction on message.
  final TextStyle? reactedUserCountTextStyle;

  /// Used for giving text style to total count of reaction text.
  final TextStyle? reactionCountTextStyle;

  /// Provides configurations for reaction bottom sheet which shows reacted users
  /// and their reaction on any message.
  final ReactionsBottomSheetConfiguration? reactionsBottomSheetConfig;

  /// Used for giving radius to reacted user profile circle.
  final double? profileCircleRadius;

  /// Used for padding to reacted user profile circle.
  final EdgeInsets? profileCirclePadding;
}

class ReactionsBottomSheetConfiguration {
  const ReactionsBottomSheetConfiguration({
    this.bottomSheetPadding,
    this.backgroundColor,
    this.reactionWidgetDecoration,
    this.reactionWidgetPadding,
    this.reactionWidgetMargin,
    this.reactedUserTextStyle,
    this.profileCircleRadius,
    this.reactionSize,
    this.reactedUserCallback,
  });

  /// Used for giving padding of bottom sheet.
  final EdgeInsetsGeometry? bottomSheetPadding;

  /// Used for giving padding of reaction widget in bottom sheet.
  final EdgeInsetsGeometry? reactionWidgetPadding;

  /// Used for giving margin of bottom sheet.
  final EdgeInsetsGeometry? reactionWidgetMargin;

  /// Used for giving background color of bottom sheet.
  final Color? backgroundColor;

  /// Used for giving decoration reaction widget in bottom sheet.
  final BoxDecoration? reactionWidgetDecoration;

  /// Used for giving text style to reacted user name.
  final TextStyle? reactedUserTextStyle;

  /// Used for giving profile circle radius.
  final double? profileCircleRadius;

  /// Used for giving size of reaction in bottom sheet.
  final double? reactionSize;

  /// Called when user tap on reacted user from reaction list
  final ReactedUserCallback? reactedUserCallback;
}
