import 'package:flutter/material.dart';

import '../../utils/constants/constants.dart';
import '../../values/enumeration.dart';
import '../../values/typedefs.dart';

class ChatBackgroundConfiguration {
  const ChatBackgroundConfiguration({
    this.defaultGroupSeparatorConfig,
    this.backgroundColor,
    this.backgroundImage,
    this.height,
    this.width,
    this.groupSeparatorBuilder,
    this.groupedListOrder = GroupedListOrder.asc,
    this.sortEnable = false,
    this.padding,
    this.margin,
    this.messageTimeTextStyle,
    this.messageTimeIconColor,
    this.loadingWidget,
    this.messageTimeAnimationCurve = Curves.decelerate,
    this.messageSorter,
  });

  /// Provides background color of chat view.
  final Color? backgroundColor;

  /// Provides background image of chat view.
  final String? backgroundImage;

  /// Provides padding of chat view.
  final EdgeInsetsGeometry? padding;

  /// Provides margin of chat view.
  final EdgeInsetsGeometry? margin;

  /// Provides height of chat view.
  final double? height;

  /// Provides width of chat view.
  final double? width;

  /// Provides configurations of chat separator widget.
  final StringWithReturnWidget? groupSeparatorBuilder;

  /// Used to define the order of a [GroupedListView] or [SliverGroupedListView].
  final GroupedListOrder groupedListOrder;

  /// Used to enable sort in list view.
  final bool sortEnable;

  /// Used to give text style of message's time while user swipe to see time of
  /// message.
  final TextStyle? messageTimeTextStyle;

  /// Used to give colour of message's time while user swipe to see time of
  /// message.
  final Color? messageTimeIconColor;

  /// Used to give configuration of default chat separator widget.
  final DefaultGroupSeparatorConfiguration? defaultGroupSeparatorConfig;

  /// Used for giving widget while data is loading.
  final Widget? loadingWidget;

  /// Used to give curve of animation which runes while user swipe to see time of
  /// message.
  final Curve messageTimeAnimationCurve;

  /// Provides callback to sort message
  final MessageSorter? messageSorter;
}

class DefaultGroupSeparatorConfiguration {
  const DefaultGroupSeparatorConfiguration({
    this.padding,
    this.textStyle,
    this.chatSeparatorDatePattern = defaultChatSeparatorDatePattern,
  });

  /// Used for giving padding of chat separator widget.
  final EdgeInsetsGeometry? padding;

  /// Used for giving text style of chat separator widget.
  final TextStyle? textStyle;

  /// Provides pattern to separate chat
  /// Defaults to ['MMM dd, yyyy']
  /// e.g. May 21, 2024
  final String chatSeparatorDatePattern;
}
