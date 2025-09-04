import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

import '../models.dart';

class ChatBubbleConfiguration {
  const ChatBubbleConfiguration({
    this.padding,
    this.margin,
    this.maxWidth,
    this.longPressAnimationDuration,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.onDoubleTap,
    this.disableLinkPreview = false,
  });

  /// Used for giving padding of chat bubble.
  final EdgeInsetsGeometry? padding;

  /// Used for giving margin of chat bubble.
  final EdgeInsetsGeometry? margin;

  /// Used for giving maximum width of chat bubble.
  final double? maxWidth;

  /// Provides callback when user long press on chat bubble.
  final Duration? longPressAnimationDuration;

  /// Provides configuration of other users message's chat bubble.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of current user message's chat bubble.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides callback when user tap twice on chat bubble.
  final ValueSetter<Message>? onDoubleTap;

  /// A flag to disable link preview functionality.
  ///
  /// When `true`, link previews will be disabled, rendering links as plain text
  /// or standard hyperlinks without additional preview metadata.
  /// When `false`, link previews will be enabled by default (current behavior).
  ///
  /// Default value: `false`.
  final bool disableLinkPreview;
}
