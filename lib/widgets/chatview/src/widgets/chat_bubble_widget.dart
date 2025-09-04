import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';

import '../../../../utils/navigation_service.dart';

import '../extensions/extensions.dart';
import '../models/config_models/feature_active_config.dart';
import '../utils/constants/constants.dart';
import '../values/enumeration.dart';
import '../values/typedefs.dart';
import 'chat_view_inherited_widget.dart';
import 'message_time_widget.dart';
import 'message_view.dart';
import 'profile_circle.dart';
import 'reply_message_widget.dart';
import 'swipe_to_reply.dart';
import '../../../../providers/chat_provider.dart';

class ChatBubbleWidget extends StatefulWidget {
  const ChatBubbleWidget({
    required GlobalKey key,
    required this.message,
    required this.onLongPress,
    required this.slideAnimation,
    required this.onSwipe,
    this.onReplyTap,
    this.shouldHighlight = false,
    this.enableContextMenu = false,
    this.onForward,
    this.onCopy,
    this.onChoose,
    this.onReplyAction,
    this.onDelete,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.groupId,
  }) : super(key: key);

  /// Represent current instance of message.
  final Message message;

  /// Give callback once user long press on chat bubble.
  final DoubleCallBack onLongPress;

  /// Provides callback of when user swipe chat bubble for reply.
  final ValueSetter<Message> onSwipe;

  /// Provides slide animation when user swipe whole chat.
  final Animation<Offset>? slideAnimation;

  /// Provides callback when user tap on replied message upon chat bubble.
  final ValueSetter<String>? onReplyTap;

  /// Flag for when user tap on replied message and highlight actual message.
  final bool shouldHighlight;

  /// Enable CupertinoContextMenu instead of long press animation
  final bool enableContextMenu;

  /// Callback for forward action
  final MessageActionCallback? onForward;

  /// Callback for copy action
  final MessageActionCallback? onCopy;

  /// Callback for choose action
  final MessageActionCallback? onChoose;

  /// Callback for reply action (different from onReplyTap)
  final MessageActionCallback? onReplyAction;

  /// Callback for delete action
  final MessageActionCallback? onDelete;

  /// Multi-select mode state
  final bool selectionMode;

  /// Whether current message is selected
  final bool isSelected;

  /// Toggle selection for this message
  final MessageActionCallback? onToggleSelect;

  /// Group ID for mention context (optional)
  final String? groupId;

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  String get replyMessage => widget.message.replyMessage.message;

  bool get isMessageBySender => widget.message.sentBy == currentUser?.id;

  bool get isLastMessage =>
      chatController?.initialMessageList.last.id == widget.message.id;

  FeatureActiveConfig? featureActiveConfig;
  ChatController? chatController;
  ChatUser? currentUser;
  int? maxDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      featureActiveConfig = chatViewIW!.featureActiveConfig;
      chatController = chatViewIW!.chatController;
      currentUser = chatController?.currentUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user from id.
    final messagedUser = chatController?.getUserFromId(widget.message.sentBy);
    return Stack(
      children: [
        if (featureActiveConfig?.enableSwipeToSeeTime ?? true) ...[
          Visibility(
            visible: widget.slideAnimation?.value.dx == 0.0 ? false : true,
            child: Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: MessageTimeWidget(
                  messageTime: widget.message.createdAt,
                  isCurrentUser: isMessageBySender,
                ),
              ),
            ),
          ),
          SlideTransition(
            position: widget.slideAnimation!,
            child: GestureDetector(
              onTap: widget.selectionMode
                  ? () => widget.onToggleSelect?.call(widget.message)
                  : null,
              child: _chatBubbleWidget(messagedUser),
            ),
          ),
        ] else
          GestureDetector(
            onTap: widget.selectionMode
                ? () => widget.onToggleSelect?.call(widget.message)
                : null,
            child: _chatBubbleWidget(messagedUser),
          ),
      ],
    );
  }

  Widget _chatBubbleWidget(ChatUser? messagedUser) {
    final chatBubbleConfig = chatListConfig.chatBubbleConfig;
    return Container(
      padding: chatBubbleConfig?.padding ?? const EdgeInsets.only(left: 5.0),
      margin: chatBubbleConfig?.margin ?? const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMessageBySender
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.selectionMode && !isMessageBySender) _selectionTapper(),
          if (!isMessageBySender &&
              (featureActiveConfig?.enableOtherUserProfileAvatar ?? true))
            profileCircle(messagedUser),
          Expanded(child: _messagesWidgetColumn(messagedUser)),
          if (isMessageBySender) ...[getReceipt()],
          if (isMessageBySender &&
              (featureActiveConfig?.enableCurrentUserProfileAvatar ?? true))
            profileCircle(messagedUser),
          if (widget.selectionMode && isMessageBySender) _selectionTapper(),
        ],
      ),
    );
  }

  Widget _selectionCheck() {
    final double size = 22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? const Color(0xFF3B82F6) : Colors.grey,
          width: 2,
        ),
        color: widget.isSelected ? const Color(0xFF3B82F6) : Colors.white,
      ),
      child: widget.isSelected
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }

  Widget _selectionTapper() {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: InkWell(
          onTap: () => widget.onToggleSelect?.call(widget.message),
          customBorder: const CircleBorder(),
          child: _selectionCheck(),
        ),
      ),
    );
  }

  ProfileCircle profileCircle(ChatUser? messagedUser) {
    final profileCircleConfig = chatListConfig.profileCircleConfig;
    return ProfileCircle(
      bottomPadding: widget.message.reaction.reactions.isNotEmpty
          ? profileCircleConfig?.bottomPadding ?? 15
          : profileCircleConfig?.bottomPadding ?? 2,
      profileCirclePadding: profileCircleConfig?.padding,
      imageUrl: messagedUser?.profilePhoto,
      displayName: messagedUser?.name ?? '',
      imageType: messagedUser?.imageType,
      defaultAvatarImage:
          messagedUser?.defaultAvatarImage ?? Constants.profileImage,
      networkImageProgressIndicatorBuilder:
          messagedUser?.networkImageProgressIndicatorBuilder,
      assetImageErrorBuilder: messagedUser?.assetImageErrorBuilder,
      networkImageErrorBuilder: messagedUser?.networkImageErrorBuilder,
      circleRadius: profileCircleConfig?.circleRadius,
      onTap: () => _onAvatarTap(messagedUser),
      onLongPress: () => _onAvatarLongPress(messagedUser),
    );
  }

  void onRightSwipe() {
    if (maxDuration != null) {
      widget.message.voiceMessageDuration = Duration(
        milliseconds: maxDuration!,
      );
    }
    if (chatListConfig.swipeToReplyConfig?.onRightSwipe != null) {
      chatListConfig.swipeToReplyConfig?.onRightSwipe!(
        widget.message.message,
        widget.message.sentBy,
      );
    }
    widget.onSwipe(widget.message);
  }

  void onLeftSwipe() {
    if (maxDuration != null) {
      widget.message.voiceMessageDuration = Duration(
        milliseconds: maxDuration!,
      );
    }
    if (chatListConfig.swipeToReplyConfig?.onLeftSwipe != null) {
      chatListConfig.swipeToReplyConfig?.onLeftSwipe!(
        widget.message.message,
        widget.message.sentBy,
      );
    }
    widget.onSwipe(widget.message);
  }

  void _onAvatarTap(ChatUser? user) {
    // In selection mode, tapping avatar should toggle selection instead of opening profile
    if (widget.selectionMode) {
      widget.onToggleSelect?.call(widget.message);
      return;
    }

    // Navigate to ContactCardScreen if user is available
    if (user != null && user.id.isNotEmpty) {
      // Debug log for avatar tap
      // Logger could be used here if needed

      return;
    }

    // Fallback to config callback if available
    if (chatListConfig.profileCircleConfig?.onAvatarTap != null &&
        user != null) {
      chatListConfig.profileCircleConfig?.onAvatarTap!(user);
    }
  }

  Widget getReceipt() {
    final showReceipts =
        chatListConfig
            .chatBubbleConfig
            ?.outgoingChatBubbleConfig
            ?.receiptsWidgetConfig
            ?.showReceiptsIn ??
        ShowReceiptsIn.lastMessage;

    Widget buildReceipts(MessageStatus status) {
      final receiptsBuilder =
          chatListConfig
              .chatBubbleConfig
              ?.outgoingChatBubbleConfig
              ?.receiptsWidgetConfig
              ?.receiptsBuilder ??
          sendMessageAnimationBuilder;
      final base = receiptsBuilder(status);

      // If undelivered, wrap with larger tap target for retry UX
      if (status == MessageStatus.undelivered) {
        return Semantics(
          label: 'Retry sending message',
          button: true,
          child: InkWell(
            onTap: _onRetryTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(8.0), // enlarge tap target to 36x36
              child: base,
            ),
          ),
        );
      }
      return base;
    }

    if (showReceipts == ShowReceiptsIn.all) {
      return ValueListenableBuilder<MessageStatus>(
        valueListenable: widget.message.statusNotifier,
        builder: (context, value, child) {
          final visible =
              ChatViewInheritedWidget.of(
                context,
              )?.featureActiveConfig.receiptsBuilderVisibility ??
              true;
          if (!visible) return const SizedBox();
          return buildReceipts(value);
        },
      );
    } else if (showReceipts == ShowReceiptsIn.lastMessage && isLastMessage) {
      return ValueListenableBuilder<MessageStatus>(
        valueListenable: chatController!.initialMessageList.last.statusNotifier,
        builder: (context, value, child) {
          final visible =
              ChatViewInheritedWidget.of(
                context,
              )?.featureActiveConfig.receiptsBuilderVisibility ??
              true;
          if (!visible) return sendMessageAnimationBuilder(value);
          return buildReceipts(value);
        },
      );
    }
    return const SizedBox();
  }

  void _onRetryTap() async {
    try {
      HapticFeedback.selectionClick();
      final wkMsg = _findWKMsgByClientMsgNo(widget.message.id);
      if (wkMsg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy nội dung để gửi lại')),
        );
        return;
      }

      // Prepare data to resend
      final content = wkMsg.messageContent;
      if (content == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi lại tin nhắn này')),
        );
        return;
      }
      final channel = WKChannel(wkMsg.channelID, wkMsg.channelType);

      // 1) Remove the failed message locally to avoid "loading mãi mãi"
      try {
        await WKIM.shared.messageManager.deleteWithClientMsgNo(
          wkMsg.clientMsgNO,
        );
      } catch (_) {}
      try {
        // Also remove from ChatController list and notify stream listeners
        final list = chatController?.initialMessageList;
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == widget.message.id);
          if (idx != -1) {
            list.removeAt(idx);
            final stream = chatController?.messageStreamController;
            if (stream != null && !stream.isClosed) {
              stream.sink.add(List<Message>.from(list));
            }
          }
        }
      } catch (_) {}

      // 2) Send as a fresh message
      WKIM.shared.messageManager.sendMessage(content, channel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi lại thất bại: $e')));
      }
    }
  }

  WKMsg? _findWKMsgByClientMsgNo(String clientMsgNo) {
    try {
      // Access provider to get WK messages list
      final nav = NavigationService.navigatorKey;
      final ctx = nav.currentContext;
      if (ctx == null) return null;
      final chatProvider = Provider.of<ChatProvider>(ctx, listen: false);
      return chatProvider.messages
              .firstWhere(
                (m) => m.clientMsgNO == clientMsgNo,
                orElse: () => WKMsg(),
              )
              .clientMsgNO
              .isEmpty
          ? null
          : chatProvider.messages.firstWhere(
              (m) => m.clientMsgNO == clientMsgNo,
            );
    } catch (_) {
      return null;
    }
  }

  void _onAvatarLongPress(ChatUser? user) {
    if (chatListConfig.profileCircleConfig?.onAvatarLongPress != null &&
        user != null) {
      chatListConfig.profileCircleConfig?.onAvatarLongPress!(user);
    }
  }

  Widget _messagesWidgetColumn(ChatUser? messagedUser) {
    return Column(
      crossAxisAlignment: isMessageBySender
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if ((chatController?.otherUsers.isNotEmpty ?? false) &&
            !isMessageBySender &&
            (featureActiveConfig?.enableOtherUserName ?? true))
          Padding(
            padding:
                chatListConfig
                    .chatBubbleConfig
                    ?.inComingChatBubbleConfig
                    ?.padding ??
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _buildSenderLabel(messagedUser),
              style: chatListConfig
                  .chatBubbleConfig
                  ?.inComingChatBubbleConfig
                  ?.senderNameTextStyle,
            ),
          ),
        if (replyMessage.isNotEmpty)
          chatListConfig.repliedMessageConfig?.repliedMessageWidgetBuilder !=
                  null
              ? chatListConfig
                    .repliedMessageConfig!
                    .repliedMessageWidgetBuilder!(widget.message.replyMessage)
              : ReplyMessageWidget(
                  message: widget.message,
                  repliedMessageConfig: chatListConfig.repliedMessageConfig,
                  onTap: (widget.onReplyTap != null && !widget.selectionMode)
                      ? () => widget.onReplyTap!(
                          widget.message.replyMessage.messageId,
                        )
                      : null,
                ),
        SwipeToReply(
          isMessageByCurrentUser: isMessageBySender,
          onSwipe: isMessageBySender ? onLeftSwipe : onRightSwipe,
          child: MessageView(
            outgoingChatBubbleConfig:
                chatListConfig.chatBubbleConfig?.outgoingChatBubbleConfig,
            isLongPressEnable:
                (featureActiveConfig?.enableReactionPopup ?? true) ||
                (featureActiveConfig?.enableReplySnackBar ?? true),
            inComingChatBubbleConfig:
                chatListConfig.chatBubbleConfig?.inComingChatBubbleConfig,
            message: widget.message,
            isMessageBySender: isMessageBySender,
            messageConfig: chatListConfig.messageConfig,
            onLongPress: widget.onLongPress,
            chatBubbleMaxWidth: chatListConfig.chatBubbleConfig?.maxWidth,
            longPressAnimationDuration:
                chatListConfig.chatBubbleConfig?.longPressAnimationDuration,
            onDoubleTap: featureActiveConfig?.enableDoubleTapToLike ?? false
                ? chatListConfig.chatBubbleConfig?.onDoubleTap ??
                      (message) => currentUser != null
                          ? chatController?.setReaction(
                              emoji: heart,
                              messageId: message.id,
                              userId: currentUser!.id,
                            )
                          : null
                : null,
            shouldHighlight: widget.shouldHighlight,
            controller: chatController,
            highlightColor:
                chatListConfig
                    .repliedMessageConfig
                    ?.repliedMsgAutoScrollConfig
                    .highlightColor ??
                Colors.grey,
            highlightScale:
                chatListConfig
                    .repliedMessageConfig
                    ?.repliedMsgAutoScrollConfig
                    .highlightScale ??
                1.1,
            onMaxDuration: _onMaxDuration,
            enableContextMenu: widget.enableContextMenu,
            onForward: widget.onForward,
            onCopy: widget.onCopy,
            onChoose: widget.onChoose,
            onReply: widget.onReplyAction,
            onDelete: widget.onDelete,
            groupId: widget.groupId,
          ),
        ),
      ],
    );
  }

  String _buildSenderLabel(ChatUser? user) {
    final base = user?.name.trim() ?? '';
    if (base.isEmpty) return '';

    final clientMsgNo = widget.message.id;
    if (clientMsgNo.isEmpty) return base;

    final os = _osFromClientMsgNo(clientMsgNo);
    return '$base/$os';
  }

  String _osFromClientMsgNo(String clientMsgNo) {
    if (clientMsgNo.endsWith('1')) return 'Android';
    if (clientMsgNo.endsWith('2')) return 'iOS';
    if (clientMsgNo.endsWith('3')) return 'Web';
    if (clientMsgNo.endsWith('5')) return 'Flutter';
    return 'PC';
  }

  void _onMaxDuration(int duration) => maxDuration = duration;
}
