import 'package:flutter/material.dart';

import '../extensions/extensions.dart';
import 'reply_icon.dart';

class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    Key? key,
    required this.onSwipe,
    required this.child,
    this.isMessageByCurrentUser = true,
  }) : super(key: key);

  /// Provides callback when user swipes chat bubble from left side.
  final VoidCallback onSwipe;

  /// Allow user to set widget which is showed while user swipes chat bubble.
  final Widget child;

  /// A boolean variable that indicates if the message is sent by the current user.
  ///
  /// This is `true` if the message is authored by the sender (the current user),
  /// and `false` if it is authored by someone else.
  final bool isMessageByCurrentUser;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double paddingValue = 0;
  double trackPaddingValue = 0;
  double initialTouchPoint = 0;
  bool isCallBackTriggered = false;

  late bool isMessageByCurrentUser = widget.isMessageByCurrentUser;

  final paddingLimit = 50;
  final double replyIconSize = 25;

  @override
  Widget build(BuildContext context) {
    return !(chatViewIW?.featureActiveConfig.enableSwipeToReply ?? true)
        ? widget.child
        : GestureDetector(
            onHorizontalDragStart: (details) =>
                initialTouchPoint = details.globalPosition.dx,
            onHorizontalDragEnd: (details) => setState(() {
              paddingValue = 0;
              isCallBackTriggered = false;
            }),
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            child: Stack(
              alignment: isMessageByCurrentUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              fit: StackFit.passthrough,
              children: [
                ReplyIcon(
                  replyIconSize: replyIconSize,
                  animationValue: paddingValue > replyIconSize
                      ? (paddingValue) / (paddingLimit)
                      : 0.0,
                ),
                Padding(
                  padding: EdgeInsets.only(
                    right: isMessageByCurrentUser ? paddingValue : 0,
                    left: isMessageByCurrentUser ? 0 : paddingValue,
                  ),
                  child: widget.child,
                ),
              ],
            ),
          );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final swipeDistance = isMessageByCurrentUser
        ? (initialTouchPoint - details.globalPosition.dx)
        : (details.globalPosition.dx - initialTouchPoint);
    if (swipeDistance >= 0 && trackPaddingValue < paddingLimit) {
      setState(() {
        paddingValue = swipeDistance;
      });
    } else if (paddingValue >= paddingLimit) {
      if (!isCallBackTriggered) {
        widget.onSwipe();
        isCallBackTriggered = true;
      }
    } else {
      setState(() {
        paddingValue = 0;
      });
    }
    trackPaddingValue = swipeDistance;
  }
}
