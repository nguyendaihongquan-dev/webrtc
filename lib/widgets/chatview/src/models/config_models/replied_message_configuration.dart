import 'package:flutter/material.dart';

import '../../values/typedefs.dart';
import 'replied_msg_auto_scroll_config.dart';

class RepliedMessageConfiguration {
  const RepliedMessageConfiguration({
    this.verticalBarColor,
    this.backgroundColor,
    this.textStyle,
    this.replyTitleTextStyle,
    this.margin,
    this.padding,
    this.maxWidth,
    this.borderRadius,
    this.verticalBarWidth,
    this.repliedImageMessageHeight,
    this.repliedImageMessageWidth,
    this.repliedMessageWidgetBuilder,
    this.opacity,
    this.repliedMsgAutoScrollConfig = const RepliedMsgAutoScrollConfig(),
    this.micIconColor,
  });

  /// Used to give color to vertical bar.
  final Color? verticalBarColor;

  /// Used to give background color to replied message widget.
  final Color? backgroundColor;

  /// Used to give text style to reply message.
  final TextStyle? textStyle;

  /// Used to give text style to replied message widget's title
  final TextStyle? replyTitleTextStyle;

  /// Used to give margin in replied message widget.
  final EdgeInsetsGeometry? margin;

  /// Used to give padding in replied message widget.
  final EdgeInsetsGeometry? padding;

  /// Used to give max width in replied message widget.
  final double? maxWidth;

  /// Used to give border radius in replied message widget.
  final BorderRadiusGeometry? borderRadius;

  /// Used to give width to vertical bar in replied message widget.
  final double? verticalBarWidth;

  /// Used to give height of image when there is image in replied message.
  final double? repliedImageMessageHeight;

  /// Used to give width of image when there is image in replied message.
  final double? repliedImageMessageWidth;

  /// Used to give opacity of replied message.
  final double? opacity;

  /// Provides builder for custom view of replied message.
  final ReplyMessageWithReturnWidget? repliedMessageWidgetBuilder;

  /// Configuration for auto scrolling and highlighting a message when
  /// tapping on the original message above the replied message.
  final RepliedMsgAutoScrollConfig repliedMsgAutoScrollConfig;

  /// Color for microphone icon.
  final Color? micIconColor;
}
