import 'dart:async';
import 'dart:io' if (kIsWeb) 'dart:html';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../chatview.dart';
import '../extensions/extensions.dart';
import 'chat_groupedlist_widget.dart';
import 'reply_popup_widget.dart';

class ChatListWidget extends StatefulWidget {
  const ChatListWidget({
    Key? key,
    required this.chatController,
    required this.assignReplyMessage,
    this.loadingWidget,
    this.loadMoreData,
    this.isLastPage,
    this.onChatListTap,
    this.textFieldConfig,
    this.onForwardMessage,
    this.onChooseMessage,
    this.onDeleteMessage,
    this.selectionMode = false,
    this.selectedIds = const <String>{},
    this.onToggleSelect,
    this.groupId,
  }) : super(key: key);

  /// Provides controller for accessing few function for running chat.
  final ChatController chatController;

  /// Provides widget for loading view while pagination is enabled.
  final Widget? loadingWidget;

  /// Provides callback when user actions reaches to top and needs to load more
  /// chat
  final ValueGetter<Future<void>>? loadMoreData;

  /// Provides flag if there is no more next data left in list.
  final bool? isLastPage;

  /// Provides callback for assigning reply message when user swipe to chat
  /// bubble.
  final ValueSetter<Message> assignReplyMessage;

  /// Provides callback when user tap anywhere on whole chat.
  final VoidCallback? onChatListTap;

  /// Provides configuration for text field config.
  final TextFieldConfiguration? textFieldConfig;

  /// Provides callback for forwarding message with proper content type handling.
  final ValueSetter<Message>? onForwardMessage;

  /// Callback when user taps "Choose" from the context menu of a message.
  final ValueSetter<Message>? onChooseMessage;

  /// Callback to bubble delete action to parent (e.g., ChatScreen)
  final ValueSetter<Message>? onDeleteMessage;

  /// Whether multi-select mode is active
  final bool selectionMode;

  /// Selected message ids (clientMsgNO)
  final Set<String> selectedIds;

  /// Toggle selection for a message
  final ValueSetter<Message>? onToggleSelect;

  /// Group ID for mention context (optional)
  final String? groupId;

  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> {
  final ValueNotifier<bool> _isNextPageLoading = ValueNotifier<bool>(false);

  ChatController get chatController => widget.chatController;

  List<Message> get messageList => chatController.initialMessageList;

  ScrollController get scrollController => chatController.scrollController;

  FeatureActiveConfig? featureActiveConfig;
  ChatUser? currentUser;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      featureActiveConfig = chatViewIW!.featureActiveConfig;
      currentUser = chatViewIW!.chatController.currentUser;
    }
    if (featureActiveConfig?.enablePagination ?? false) {
      // When flag is on then it will include pagination logic to scroll
      // controller.
      scrollController.addListener(_pagination);
    }
  }

  void _initialize() {
    chatController.messageStreamController = StreamController();
    if (!chatController.messageStreamController.isClosed) {
      chatController.messageStreamController.sink.add(messageList);
    }
    if (messageList.isNotEmpty) chatController.scrollToLastMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _isNextPageLoading,
          builder: (_, isNextPageLoading, child) {
            if (isNextPageLoading &&
                (featureActiveConfig?.enablePagination ?? false)) {
              return SizedBox(
                height: Scaffold.of(context).appBarMaxHeight,
                child: Center(
                  child:
                      widget.loadingWidget ?? const CircularProgressIndicator(),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: chatViewIW!.showPopUp,
            builder: (_, showPopupValue, child) {
              return Stack(
                children: [
                  ChatGroupedListWidget(
                    showPopUp: showPopupValue,
                    scrollController: scrollController,
                    isEnableSwipeToSeeTime:
                        featureActiveConfig?.enableSwipeToSeeTime ?? true,
                    assignReplyMessage: widget.assignReplyMessage,
                    onChatBubbleLongPress: (yCoordinate, xCoordinate, message) {
                      if (featureActiveConfig?.enableReactionPopup ?? false) {
                        chatViewIW?.reactionPopupKey.currentState
                            ?.refreshWidget(
                              message: message,
                              xCoordinate: xCoordinate,
                              yCoordinate: yCoordinate,
                            );
                        chatViewIW?.showPopUp.value = true;
                      }
                      if (featureActiveConfig?.enableReplySnackBar ?? false) {
                        _showReplyPopup(
                          message: message,
                          sentByCurrentUser: message.sentBy == currentUser?.id,
                        );
                      }
                    },
                    onChatListTap: _onChatListTap,
                    textFieldConfig: widget.textFieldConfig,
                    enableContextMenu: true, // Enable context menu by default
                    onForward: _onForwardMessage,
                    onCopy: _onCopyMessage,
                    onChoose: _onChooseMessage,
                    onReplyAction: _onReplyMessage,
                    onDelete: _onDeleteMessage,
                    selectionMode: widget.selectionMode,
                    selectedIds: widget.selectedIds,
                    onToggleSelect: widget.onToggleSelect,
                    groupId: widget.groupId,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _pagination() {
    if (widget.loadMoreData == null || widget.isLastPage == true) return;
    if ((scrollController.position.pixels ==
            scrollController.position.maxScrollExtent) &&
        !_isNextPageLoading.value) {
      _isNextPageLoading.value = true;
      widget.loadMoreData!().whenComplete(
        () => _isNextPageLoading.value = false,
      );
    }
  }

  void _showReplyPopup({
    required Message message,
    required bool sentByCurrentUser,
  }) {
    final replyPopup = chatListConfig.replyPopupConfig;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(hours: 1),
          backgroundColor: replyPopup?.backgroundColor ?? Colors.white,
          content: replyPopup?.replyPopupBuilder != null
              ? replyPopup!.replyPopupBuilder!(message, sentByCurrentUser)
              : ReplyPopupWidget(
                  buttonTextStyle: replyPopup?.buttonTextStyle,
                  topBorderColor: replyPopup?.topBorderColor,
                  onMoreTap: () {
                    _onChatListTap();
                    replyPopup?.onMoreTap?.call(message, sentByCurrentUser);
                  },
                  onReportTap: () {
                    _onChatListTap();
                    replyPopup?.onReportTap?.call(message);
                  },
                  onUnsendTap: () {
                    _onChatListTap();
                    replyPopup?.onUnsendTap?.call(message);
                  },
                  onReplyTap: () {
                    widget.assignReplyMessage(message);
                    if (featureActiveConfig?.enableReactionPopup ?? false) {
                      chatViewIW?.showPopUp.value = false;
                    }
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    if (replyPopup?.onReplyTap != null) {
                      replyPopup?.onReplyTap!(message);
                    }
                  },
                  sentByCurrentUser: sentByCurrentUser,
                ),
          padding: EdgeInsets.zero,
        ),
      ).closed;
  }

  void _onChatListTap() {
    widget.onChatListTap?.call();
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      FocusScope.of(context).unfocus();
    }
    chatViewIW?.showPopUp.value = false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _onForwardMessage(Message message) {
    // Hide any popups first
    _onChatListTap();

    // Use the callback if provided, otherwise fallback to simple text forwarding
    if (widget.onForwardMessage != null) {
      widget.onForwardMessage!(message);
    }
  }

  void _onCopyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onChooseMessage(Message message) {
    // Bubble up to parent for multi-select handling
    if (widget.onChooseMessage != null) {
      widget.onChooseMessage!(message);
    }
  }

  void _onReplyMessage(Message message) {
    // Use existing reply functionality
    widget.assignReplyMessage(message);
  }

  void _onDeleteMessage(Message message) {
    // Hide any popups first
    _onChatListTap();

    // Bubble up to parent (e.g., ChatScreen) to handle delete logic
    if (widget.onDeleteMessage != null) {
      widget.onDeleteMessage!(message);
    }
  }

  @override
  void dispose() {
    _isNextPageLoading.dispose();
    super.dispose();
  }
}
