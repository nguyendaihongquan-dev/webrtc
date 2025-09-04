import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

import '../../values/typedefs.dart';

class ReplyPopupConfiguration {
  const ReplyPopupConfiguration({
    this.buttonTextStyle,
    this.topBorderColor,
    this.onUnsendTap,
    this.onReplyTap,
    this.onReportTap,
    this.onMoreTap,
    this.backgroundColor,
    this.replyPopupBuilder,
  });

  /// Used for giving background color to reply snack-bar.
  final Color? backgroundColor;

  /// Provides builder for creating reply pop-up widget.
  final ReplyPopupBuilder? replyPopupBuilder;

  /// Provides callback on unSend button.
  final ValueSetter<Message>? onUnsendTap;

  /// Provides callback on onReply button.
  final ValueSetter<Message>? onReplyTap;

  /// Provides callback on onReport button.
  final ValueSetter<Message>? onReportTap;

  /// Provides callback on onMore button.
  final MoreTapCallBack? onMoreTap;

  /// Used to give text style of button text.
  final TextStyle? buttonTextStyle;

  /// Used to give color to top side border of reply snack bar.
  final Color? topBorderColor;
}
