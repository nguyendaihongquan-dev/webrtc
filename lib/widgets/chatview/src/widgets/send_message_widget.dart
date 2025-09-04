import 'dart:io' if (kIsWeb) 'dart:html';

import 'package:chatview_utils/chatview_utils.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../extensions/extensions.dart';
import '../models/config_models/message_configuration.dart';
import '../models/config_models/send_message_configuration.dart';
import '../utils/constants/constants.dart';
import '../values/typedefs.dart';
import 'chatui_textfield.dart';
import 'chat_textfield_view_builder.dart';
import 'reply_message_view.dart';
import 'scroll_to_bottom_button.dart';
import 'selected_image_view_widget.dart';
import '../../../../controllers/mention_text_controller.dart';
import '../../../../models/wk_mention_text_content.dart';
import '../../../../widgets/mention_suggestions.dart';
import '../../../../utils/logger.dart';

class SendMessageWidget extends StatefulWidget {
  const SendMessageWidget({
    Key? key,
    required this.onSendTap,
    this.sendMessageConfig,
    this.sendMessageBuilder,
    this.messageConfig,
    this.replyMessageBuilder,
    this.channelId,
    this.channelType,
    this.onMentionSendTap,
  }) : super(key: key);

  /// Provides call back when user tap on send button on text field.
  final StringMessageCallBack onSendTap;

  /// Provides configuration for text field appearance.
  final SendMessageConfiguration? sendMessageConfig;

  /// Allow user to set custom text field.
  final ReplyMessageWithReturnWidget? sendMessageBuilder;

  /// Provides configuration of all types of messages.
  final MessageConfiguration? messageConfig;

  /// Provides a callback for the view when replying to message
  final CustomViewForReplyMessage? replyMessageBuilder;

  /// Channel ID for mention functionality
  final String? channelId;

  /// Channel type for mention functionality
  final int? channelType;

  /// Callback for mention messages
  final Function(
    WKMentionTextContent mentionContent,
    ReplyMessage replyMessage,
  )?
  onMentionSendTap;

  @override
  State<SendMessageWidget> createState() => SendMessageWidgetState();
}

class SendMessageWidgetState extends State<SendMessageWidget> {
  late final MentionTextController _textEditingController;

  final _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showSuggestions = false;
  String _currentQuery = '';

  final GlobalKey<ReplyMessageViewState> _replyMessageTextFieldViewKey =
      GlobalKey();

  final GlobalKey<SelectedImageViewWidgetState> _selectedImageViewWidgetKey =
      GlobalKey();
  ReplyMessage _replyMessage = const ReplyMessage();

  ChatUser? currentUser;

  // Emoji state
  final ValueNotifier<bool> _isEmojiVisible = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    // Initialize MentionTextController with callbacks
    _textEditingController = MentionTextController(
      onMentionTriggered: _onMentionTriggered,
      onMentionCancelled: _onMentionCancelled,
      onEntitiesChanged: _onEntitiesChanged,
    );

    // Prefill initial draft text if provided via TextFieldConfiguration
    final initialDraft = widget.sendMessageConfig?.textFieldConfig?.initialText;
    if (initialDraft != null && initialDraft.isNotEmpty) {
      _textEditingController.text = initialDraft;
      _textEditingController.selection = TextSelection.collapsed(
        offset: initialDraft.length,
      );
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _isEmojiVisible.value) {
        _isEmojiVisible.value = false;
      }

      // Hide suggestions when focus is lost
      if (!_focusNode.hasFocus) {
        _hideOverlay();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      currentUser = chatViewIW!.chatController.currentUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollToBottomButtonConfig =
        chatListConfig.scrollToBottomButtonConfig;
    return Align(
      alignment: Alignment.bottomCenter,
      child: widget.sendMessageBuilder != null
          ? widget.sendMessageBuilder!(_replyMessage)
          : SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  // This has been added to prevent messages from being
                  // displayed below the text field
                  // when the user scrolls the message list.
                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Container(
                      height:
                          MediaQuery.of(context).size.height /
                          ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                      color:
                          chatListConfig.chatBackgroundConfig.backgroundColor ??
                          Colors.white,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chatViewIW
                                ?.featureActiveConfig
                                .enableScrollToBottomButton ??
                            true)
                          Align(
                            alignment:
                                scrollToBottomButtonConfig
                                    ?.alignment
                                    ?.alignment ??
                                Alignment.bottomCenter,
                            child: Padding(
                              padding:
                                  scrollToBottomButtonConfig?.padding ??
                                  EdgeInsets.zero,
                              child: const ScrollToBottomButton(),
                            ),
                          ),
                        Padding(
                          key: chatViewIW?.chatTextFieldViewKey,
                          padding: EdgeInsets.fromLTRB(
                            bottomPadding4,
                            bottomPadding4,
                            bottomPadding4,
                            _bottomPadding,
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              ReplyMessageView(
                                key: _replyMessageTextFieldViewKey,
                                sendMessageConfig: widget.sendMessageConfig,
                                messageConfig: widget.messageConfig,
                                builder: widget.replyMessageBuilder,
                                onChange: (value) => _replyMessage = value,
                              ),
                              if (widget
                                      .sendMessageConfig
                                      ?.shouldSendImageWithText ??
                                  false)
                                SelectedImageViewWidget(
                                  key: _selectedImageViewWidgetKey,
                                  sendMessageConfig: widget.sendMessageConfig,
                                ),
                              // Input and emoji toggle
                              ChatTextFieldViewBuilder<bool>(
                                valueListenable: _isEmojiVisible,
                                builder: (context, isEmoji, __) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CompositedTransformTarget(
                                        link: _layerLink,
                                        child: ChatUITextField(
                                          focusNode: _focusNode,
                                          textEditingController:
                                              _textEditingController,
                                          onPressed: _onPressed,
                                          sendMessageConfig:
                                              widget.sendMessageConfig,
                                          onRecordingComplete:
                                              _onRecordingComplete,
                                          onImageSelected: (images, messageId) {
                                            if (widget
                                                    .sendMessageConfig
                                                    ?.shouldSendImageWithText ??
                                                false) {
                                              if (images.isNotEmpty) {
                                                _selectedImageViewWidgetKey
                                                    .currentState
                                                    ?.selectedImages
                                                    .value = [
                                                  ...?_selectedImageViewWidgetKey
                                                      .currentState
                                                      ?.selectedImages
                                                      .value,
                                                  images,
                                                ];

                                                FocusScope.of(
                                                  context,
                                                ).requestFocus(_focusNode);
                                              }
                                            } else {
                                              _onImageSelected(images, '');
                                            }
                                          },
                                          // Pass context/channel and onSendTap for custom actions (e.g., Card)
                                          channelId: widget.channelId,
                                          channelType: widget.channelType,
                                          onSendTap: widget.onSendTap,
                                          onEmojiToggle: () {
                                            // Toggle emoji panel
                                            if (_isEmojiVisible.value) {
                                              _isEmojiVisible.value = false;
                                              _focusNode.requestFocus();
                                            } else {
                                              _focusNode.unfocus();
                                              _isEmojiVisible.value = true;
                                            }
                                          },
                                          isEmojiVisible: isEmoji,
                                        ),
                                      ),
                                      // Emoji Picker panel
                                      if (isEmoji) _buildEmojiPanel(context),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _onRecordingComplete(String? path) {
    if (path != null) {
      widget.onSendTap.call(path, _replyMessage, MessageType.voice);
      onCloseTap();
    }
  }

  void _onImageSelected(String imagePath, String error) {
    debugPrint('Call in Send Message Widget');
    if (imagePath.isNotEmpty) {
      widget.onSendTap.call(imagePath, _replyMessage, MessageType.image);
      onCloseTap();
    }
  }

  void _onPressed() {
    final messageText = _textEditingController.text.trim();
    if (messageText.isEmpty) return;

    // 🔧 FIX: Get mention content with entities
    final mentionContent = _textEditingController.getMentionTextContent();

    Logger.service(
      'SendMessageWidget',
      '🏷️ Sending message: "$messageText" with ${mentionContent.mentionEntities.length} mentions',
    );

    // Log mention details for debugging
    for (final entity in mentionContent.mentionEntities) {
      Logger.service(
        'SendMessageWidget',
        '🏷️ Mention entity: ${entity.displayName} (${entity.value}) at ${entity.offset}-${entity.offset + entity.length}',
      );
    }

    // Handle images if any
    if (_selectedImageViewWidgetKey.currentState?.selectedImages.value
        case final selectedImages?) {
      for (final image in selectedImages) {
        _onImageSelected(image, '');
      }
      _selectedImageViewWidgetKey.currentState?.selectedImages.value = [];
    }

    // 🔧 FIX: Use mention-specific callback if available and has mentions
    if (widget.onMentionSendTap != null &&
        mentionContent.mentionEntities.isNotEmpty) {
      Logger.service('SendMessageWidget', '🏷️ Using mention callback');
      widget.onMentionSendTap!(mentionContent, _replyMessage);
    } else {
      // Fallback to regular text callback
      Logger.service('SendMessageWidget', '📝 Using regular text callback');
      widget.onSendTap.call(messageText, _replyMessage, MessageType.text);
    }

    // Clear text field and mentions, then close reply
    _textEditingController.clear();

    // 🔧 FIX: Clear mentions and hide suggestions after sending
    _textEditingController.clearMentions();
    _hideOverlay(); // Hide any open mention suggestions
    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });
    Logger.service(
      'SendMessageWidget',
      '🧹 Cleared mentions and suggestions after sending',
    );

    onCloseTap();
  }

  void assignReplyMessage(Message message) {
    if (currentUser == null) {
      return;
    }
    FocusScope.of(context).requestFocus(_focusNode);
    _replyMessage = ReplyMessage(
      message: message.message,
      replyBy: currentUser!.id,
      replyTo: message.sentBy,
      messageType: message.messageType,
      messageId: message.id,
      voiceMessageDuration: message.voiceMessageDuration,
    );

    if (_replyMessageTextFieldViewKey.currentState == null) {
      setState(() {});
    } else {
      _replyMessageTextFieldViewKey.currentState!.replyMessage.value =
          _replyMessage;
    }
  }

  void onCloseTap() {
    if (_replyMessageTextFieldViewKey.currentState == null) {
      setState(() {
        _replyMessage = const ReplyMessage();
      });
    } else {
      _replyMessageTextFieldViewKey.currentState?.onClose();
    }
    // Close emoji when closing composer contexts
    if (_isEmojiVisible.value) {
      _isEmojiVisible.value = false;
    }
  }

  /// Programmatically hide emoji panel (called by parent on outside taps)
  void hideEmojiPanel() {
    if (_isEmojiVisible.value) {
      _isEmojiVisible.value = false;
    }
  }

  double get _bottomPadding => (!kIsWeb && Platform.isIOS)
      ? (_focusNode.hasFocus
            ? bottomPadding1
            : View.of(context).viewPadding.bottom > 0
            ? bottomPadding2
            : bottomPadding3)
      : bottomPadding3;

  @override
  void dispose() {
    _hideOverlay();
    _textEditingController.dispose();
    _focusNode.dispose();
    _isEmojiVisible.dispose();
    super.dispose();
  }

  // Mention functionality methods
  void _onMentionTriggered(String query, int position) {
    // Only show suggestions for group chats
    if (widget.channelType != 2 || widget.channelId == null) {
      // 2 = WKChannelType.group
      return;
    }

    Logger.service(
      'SendMessageWidget',
      'Mention triggered: "$query" at position $position',
    );

    setState(() {
      _showSuggestions = true;
      _currentQuery = query;
    });

    _showOverlay();
  }

  void _onMentionCancelled() {
    Logger.service('SendMessageWidget', 'Mention cancelled');

    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });

    _hideOverlay();
  }

  void _onEntitiesChanged(List<dynamic> entities) {
    Logger.service(
      'SendMessageWidget',
      'Entities changed: ${entities.length} mentions',
    );
  }

  void _onMemberSelected(dynamic member) {
    if (_textEditingController.currentMentionStart == null) return;

    // Get display name from member
    final displayName = (member.remark?.isNotEmpty == true)
        ? member.remark!
        : (member.name?.isNotEmpty == true ? member.name! : member.uid);

    Logger.service(
      'SendMessageWidget',
      'Member selected: $displayName (${member.uid})',
    );

    // Calculate end position
    final startPos = _textEditingController.currentMentionStart!;
    final endPos = startPos + 1 + _currentQuery.length; // +1 for @

    // Add mention
    _textEditingController.addMention(
      userId: member.uid,
      displayName: displayName,
      startPosition: startPos,
      endPosition: endPos,
    );

    // 🔧 FIX: Hide suggestions after selecting member
    _hideOverlay();
    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });

    Logger.service(
      'SendMessageWidget',
      '✅ Member selected and suggestions hidden',
    );
  }

  void _showOverlay() {
    if (_overlayEntry != null ||
        !_showSuggestions ||
        widget.channelId == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, -200), // Show above text field
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: MentionSuggestions(
              groupId: widget.channelId!,
              query: _currentQuery,
              onMemberSelected: _onMemberSelected,
              maxHeight: 200,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildEmojiPanel(BuildContext context) {
    final config = context.chatListConfig.emojiPickerSheetConfig;
    final double height = (config?.height ?? 256).toDouble();
    return SizedBox(
      height: height,
      child: EmojiPicker(
        onEmojiSelected: (Category? category, Emoji emoji) {
          final selection = _textEditingController.selection;
          final text = _textEditingController.text;
          final newText = text.replaceRange(
            selection.start,
            selection.end,
            emoji.emoji,
          );
          _textEditingController
            ..text = newText
            ..selection = TextSelection.collapsed(
              offset: selection.start + emoji.emoji.length,
            );
          // Force notify listeners so UI (send button) updates even if same value length etc.
          // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
          _textEditingController.notifyListeners();
        },
        config:
            config ??
            const Config(
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                backgroundColor: Colors.white,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: Colors.white,
              ),
            ),
      ),
    );
  }
}
