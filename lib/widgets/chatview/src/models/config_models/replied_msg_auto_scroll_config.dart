import 'package:flutter/material.dart';

class RepliedMsgAutoScrollConfig {
  /// Auto scrolls to original message when tapped on replied message.
  /// Defaults to true.
  final bool enableScrollToRepliedMsg;

  /// Highlights the text by changing background color of chat bubble for
  /// given duration. Default to true.
  final bool enableHighlightRepliedMsg;

  /// Chat bubble color when highlighted. Defaults to Colors.grey.
  final Color highlightColor;

  /// Chat will remain highlighted for this duration. Defaults to 500ms.
  final Duration highlightDuration;

  /// When replied message have image or only emojis. They will be scaled
  /// for provided [highlightDuration] to highlight them. Defaults to 1.1
  final double highlightScale;

  /// Animation curve for auto scroll. Defaults to Curves.easeIn.
  final Curve highlightScrollCurve;

  /// Configuration for auto scrolling and highlighting a message when
  /// tapping on the original message above the replied message.
  const RepliedMsgAutoScrollConfig({
    this.enableHighlightRepliedMsg = true,
    this.enableScrollToRepliedMsg = true,
    this.highlightColor = Colors.grey,
    this.highlightDuration = const Duration(milliseconds: 500),
    this.highlightScale = 1.1,
    this.highlightScrollCurve = Curves.easeIn,
  });
}
