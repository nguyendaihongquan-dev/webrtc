import 'package:flutter/material.dart';

import '../../values/typedefs.dart';

class SwipeToReplyConfiguration {
  const SwipeToReplyConfiguration({
    this.replyIconColor,
    this.replyIconProgressRingColor,
    this.replyIconBackgroundColor,
    this.onRightSwipe,
    this.onLeftSwipe,
  });

  /// Used to give color of reply icon while swipe to reply.
  final Color? replyIconColor;

  /// Used to give color of circular progress around reply icon while swipe to reply.
  final Color? replyIconProgressRingColor;

  /// Used to give color of reply icon background when swipe to reply reach swipe limit.
  final Color? replyIconBackgroundColor;

  /// Provides callback when user swipe chat bubble from left side.
  final OnMessageSwipeCallback? onLeftSwipe;

  /// Provides callback when user swipe chat bubble from right side.
  final OnMessageSwipeCallback? onRightSwipe;
}
