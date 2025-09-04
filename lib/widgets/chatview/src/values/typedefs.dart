import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

typedef StringMessageCallBack =
    void Function(
      String message,
      ReplyMessage replyMessage,
      MessageType messageType,
    );
typedef ReplyMessageWithReturnWidget =
    Widget Function(ReplyMessage? replyMessage);
typedef DoubleCallBack = void Function(double yPosition, double xPosition);
typedef StringsCallBack = void Function(String emoji, String messageId);
typedef StringWithReturnWidget = Widget Function(String separator);
typedef DragUpdateDetailsCallback = void Function(DragUpdateDetails);
typedef MoreTapCallBack =
    void Function(Message message, bool sentByCurrentUser);
typedef ReactionCallback = void Function(Message message, String emoji);
typedef ReactedUserCallback =
    void Function(ChatUser reactedUser, String reaction);

/// customMessageType view for a reply of custom message type
typedef CustomMessageReplyViewBuilder = Widget Function(ReplyMessage state);
typedef MessageSorter = int Function(Message message1, Message message2);

/// customView for replying to any message
typedef CustomViewForReplyMessage =
    Widget Function(BuildContext context, ReplyMessage state);
typedef GetMessageSeparator = (
  Map<int, DateTime> messageSeparator,
  DateTime dateTime,
);
typedef SelectedImageViewBuilder =
    Widget Function(List<String> images, ValueSetter<String> onImageRemove);
typedef CustomMessageBuilder = Widget Function(Message message);
typedef ReceiptBuilder = Widget Function(MessageStatus status);
typedef LastSeenAgoBuilder =
    Widget Function(Message message, String formattedDate);
typedef ReplyPopupBuilder =
    Widget Function(Message message, bool sentByCurrentUser);
typedef ImagePickedCallback = Future<String?> Function(String? path);
typedef OnMessageSwipeCallback = void Function(String message, String sentBy);
typedef ChatBubbleLongPressCallback =
    void Function(double yCordinate, double xCordinate, Message message);
typedef MessageActionCallback = void Function(Message message);
typedef ChatTextFieldViewBuilderCallback<T> =
    Widget Function(BuildContext context, T value, Widget? child);
