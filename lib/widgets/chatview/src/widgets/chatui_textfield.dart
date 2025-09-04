import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'dart:convert';

import '../models/config_models/send_message_configuration.dart';
import '../utils/constants/constants.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';
import '../values/typedefs.dart';
import '../../../../controllers/mention_text_controller.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    this.onEmojiToggle,
    this.isEmojiVisible = false,
    this.channelId,
    this.channelType,
    this.onSendTap,
  }) : super(key: key);

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides focusNode for focusing text field.
  final FocusNode focusNode;

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallback onPressed;

  /// Provides callback once voice is recorded.
  final ValueSetter<String?> onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  /// Toggles emoji picker visibility.
  final VoidCallback? onEmojiToggle;

  /// Indicates if emoji picker is currently visible to swap icon.
  final bool isEmojiVisible;

  /// Optional channel context for custom actions (e.g., mentions, card picker)
  final String? channelId;
  final int? channelType;

  /// Bubble up send action from custom UI actions (e.g., card send)
  final StringMessageCallBack? onSendTap;

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);
  final ValueNotifier<bool> _showOptions = ValueNotifier(false);
  VoidCallback? _controllerTextListener;

  bool Function(KeyEvent)? _keyboardHandler;

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig =>
      widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig =>
      sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig =>
      sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration =>
      sendMessageConfig?.cancelRecordConfiguration;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.transparent),
    borderRadius:
        widget.sendMessageConfig?.textFieldConfig?.borderRadius ??
        BorderRadius.circular(textFieldBorderRadius),
  );

  ValueNotifier<TypeWriterStatus> composingStatus = ValueNotifier(
    TypeWriterStatus.typed,
  );

  late Debouncer debouncer;

  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(
      sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
          const Duration(seconds: 1),
    );
    super.initState();

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      controller = RecorderController();
    }
    if (kIsWeb) {
      if (_attachHardwareKeyboardHandler() case final handler) {
        _keyboardHandler = handler;
        HardwareKeyboard.instance.addHandler(handler);
      }
    }

    // Listen controller changes (emoji insertions, programmatic updates)
    _controllerTextListener = () {
      final text = widget.textEditingController.text;
      if (_inputText.value != text) {
        _inputText.value = text;
      }

      // Rebuild for mention styling if it's a MentionTextController
      if (widget.textEditingController is MentionTextController && mounted) {
        setState(() {});
      }
    };
    widget.textEditingController.addListener(_controllerTextListener!);
  }

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    _showOptions.dispose();
    if (_keyboardHandler case final handler?) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    if (_controllerTextListener case final l?) {
      widget.textEditingController.removeListener(l);
    }
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping?.call(
        composingStatus.value,
      );
    });
  }

  // Attaches a hardware keyboard handler to handle Enter key events.
  // This is only applicable for web platforms.
  // It checks if the Enter key is pressed then sends the message
  // or inserts a new line based on whether Enter + Shift is pressed.
  bool Function(KeyEvent) _attachHardwareKeyboardHandler() {
    return (KeyEvent event) {
      if (event is! KeyDownEvent ||
          event.logicalKey != LogicalKeyboardKey.enter) {
        return false;
      }

      final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
      final isShiftPressed = pressedKeys.any(
        (key) =>
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight,
      );
      if (!isShiftPressed) {
        // Send message on Enter
        if (_inputText.value.trim().isNotEmpty) {
          widget.onPressed();
          _inputText.value = '';
        }
      } else {
        // Shift+Enter: insert new line
        final text = widget.textEditingController.text;
        final selection = widget.textEditingController.selection;

        // Insert a newline ('\n') at the current cursor position or
        // replace selected text with it.
        final newText = text.replaceRange(selection.start, selection.end, '\n');
        widget.textEditingController
          ..text = newText
          ..selection = TextSelection.collapsed(offset: selection.start + 1);
      }
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    final outlineBorder = _outLineBorder;
    return Container(
      padding:
          textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
      margin: textFieldConfig?.margin,
      decoration: BoxDecoration(
        borderRadius:
            textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
        color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: isRecording,
        builder: (_, isRecordingValue, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Plus toggle (Messenger-like)
                  ValueListenableBuilder<bool>(
                    valueListenable: _showOptions,
                    builder: (_, show, __) => IconButton(
                      constraints: const BoxConstraints(),
                      onPressed: (textFieldConfig?.enabled ?? true)
                          ? () {
                              // Close emoji panel if open
                              if (widget.isEmojiVisible) {
                                widget.onEmojiToggle?.call();
                              }
                              _showOptions.value = !show;
                            }
                          : null,
                      icon: Icon(
                        show ? Icons.close_rounded : Icons.add_circle_outline,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (isRecordingValue && controller != null && !kIsWeb)
                    Expanded(
                      child: AudioWaveforms(
                        size: const Size(double.maxFinite, 50),
                        recorderController: controller!,
                        margin: voiceRecordingConfig?.margin,
                        padding:
                            voiceRecordingConfig?.padding ??
                            EdgeInsets.symmetric(
                              horizontal: cancelRecordConfiguration == null
                                  ? 8
                                  : 5,
                            ),
                        decoration:
                            voiceRecordingConfig?.decoration ??
                            BoxDecoration(
                              color: voiceRecordingConfig?.backgroundColor,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                        waveStyle:
                            voiceRecordingConfig?.waveStyle ??
                            WaveStyle(
                              extendWaveform: true,
                              showMiddleLine: false,
                              waveColor:
                                  voiceRecordingConfig?.waveStyle?.waveColor ??
                                  Colors.black,
                            ),
                      ),
                    )
                  else
                    Expanded(child: _buildTextField(outlineBorder)),
                  ValueListenableBuilder<String>(
                    valueListenable: _inputText,
                    builder: (_, inputTextValue, child) {
                      final hasText = inputTextValue.trim().isNotEmpty;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Emoji toggle on the right
                          IconButton(
                            constraints: const BoxConstraints(),
                            onPressed: (textFieldConfig?.enabled ?? true)
                                ? () {
                                    _showOptions.value = false;
                                    widget.onEmojiToggle?.call();
                                  }
                                : null,
                            icon: Icon(
                              widget.isEmojiVisible
                                  ? Icons.keyboard_alt_outlined
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (hasText)
                            IconButton(
                              color:
                                  sendMessageConfig?.defaultSendButtonColor ??
                                  Colors.green,
                              onPressed: (textFieldConfig?.enabled ?? true)
                                  ? () {
                                      widget.onPressed();
                                      _inputText.value = '';
                                    }
                                  : null,
                              icon:
                                  sendMessageConfig?.sendButtonIcon ??
                                  const Icon(Icons.send),
                            )
                          else ...[
                            if ((sendMessageConfig?.allowRecordingVoice ??
                                    false) &&
                                !kIsWeb &&
                                (Platform.isIOS || Platform.isAndroid))
                              IconButton(
                                onPressed: (textFieldConfig?.enabled ?? true)
                                    ? _recordOrStop
                                    : null,
                                icon:
                                    (isRecordingValue
                                        ? voiceRecordingConfig?.stopIcon
                                        : voiceRecordingConfig?.micIcon) ??
                                    Icon(
                                      isRecordingValue ? Icons.stop : Icons.mic,
                                      color: voiceRecordingConfig
                                          ?.recorderIconColor,
                                    ),
                              ),
                            if (isRecordingValue &&
                                cancelRecordConfiguration != null)
                              IconButton(
                                onPressed: () {
                                  cancelRecordConfiguration?.onCancel?.call();
                                  _cancelRecording();
                                },
                                icon:
                                    cancelRecordConfiguration?.icon ??
                                    const Icon(Icons.cancel_outlined),
                                color:
                                    cancelRecordConfiguration?.iconColor ??
                                    voiceRecordingConfig?.recorderIconColor,
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              // Options tray (animated)
              ValueListenableBuilder<bool>(
                valueListenable: _showOptions,
                builder: (_, show, __) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    height: show ? 56 : 0,
                    padding: EdgeInsets.symmetric(horizontal: show ? 6 : 0),
                    child: show
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Card (Contact Card)
                              IconButton(
                                onPressed: (textFieldConfig?.enabled ?? true)
                                    ? _onSendCardPressed
                                    : null,
                                icon: const Icon(Icons.contact_mail_outlined),
                                color: Colors.grey.shade700,
                                tooltip: 'Gửi danh thiếp',
                              ),
                              // Camera
                              if (sendMessageConfig?.enableCameraImagePicker ??
                                  true)
                                IconButton(
                                  onPressed: (textFieldConfig?.enabled ?? true)
                                      ? () => _onIconPressed(
                                          ImageSource.camera,
                                          config: sendMessageConfig
                                              ?.imagePickerConfiguration,
                                        )
                                      : null,
                                  icon:
                                      imagePickerIconsConfig
                                          ?.cameraImagePickerIcon ??
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        color: imagePickerIconsConfig
                                            ?.cameraIconColor,
                                      ),
                                ),
                              // Gallery
                              if (sendMessageConfig?.enableGalleryImagePicker ??
                                  true)
                                IconButton(
                                  onPressed: (textFieldConfig?.enabled ?? true)
                                      ? () => _onIconPressed(
                                          ImageSource.gallery,
                                          config: sendMessageConfig
                                              ?.imagePickerConfiguration,
                                        )
                                      : null,
                                  icon:
                                      imagePickerIconsConfig
                                          ?.galleryImagePickerIcon ??
                                      Icon(
                                        Icons.image,
                                        color: imagePickerIconsConfig
                                            ?.galleryIconColor,
                                      ),
                                ),
                              // Voice
                              if ((sendMessageConfig?.allowRecordingVoice ??
                                      false) &&
                                  !kIsWeb &&
                                  (Platform.isIOS || Platform.isAndroid))
                                IconButton(
                                  onPressed: (textFieldConfig?.enabled ?? true)
                                      ? _recordOrStop
                                      : null,
                                  icon:
                                      voiceRecordingConfig?.micIcon ??
                                      Icon(
                                        Icons.mic,
                                        color: voiceRecordingConfig
                                            ?.recorderIconColor,
                                      ),
                                ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) return;
    final path = await controller?.stop();
    if (path == null) {
      isRecording.value = false;
      return;
    }
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    isRecording.value = false;
  }

  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      await controller?.record(
        sampleRate: voiceRecordingConfig?.sampleRate,
        bitRate: voiceRecordingConfig?.bitRate,
        androidEncoder: voiceRecordingConfig?.androidEncoder,
        iosEncoder: voiceRecordingConfig?.iosEncoder,
        androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
      );
      isRecording.value = true;
    } else {
      final path = await controller?.stop();
      isRecording.value = false;
      widget.onRecordingComplete(path);
    }
  }

  Future<void> _onSendCardPressed() async {
    try {
      // Navigate to choose contact screen and get selected UID
    } catch (e) {
      debugPrint('Failed to send card: $e');
    }
  }

  void _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    final hasFocus = widget.focusNode.hasFocus;
    try {
      widget.focusNode.unfocus();

      if (imageSource == ImageSource.camera) {
        // Use wechat_camera_picker for camera
        final AssetEntity? entity = await CameraPicker.pickFromCamera(
          context,
          pickerConfig: CameraPickerConfig(
            enableRecording: false, // Only photos
            maximumRecordingDuration: const Duration(seconds: 15),
            theme: CameraPicker.themeData(Theme.of(context).primaryColor),
          ),
        );

        if (entity != null) {
          final File? file = await entity.file;
          if (file != null) {
            String imagePath = file.path;
            if (config?.onImagePicked != null) {
              String? updatedImagePath = await config?.onImagePicked!(
                imagePath,
              );
              if (updatedImagePath != null) imagePath = updatedImagePath;
            }
            widget.onImageSelected(imagePath, '');
          }
        }
      } else {
        // Use wechat_assets_picker for gallery
        final List<AssetEntity>? assets = await AssetPicker.pickAssets(
          context,
          pickerConfig: AssetPickerConfig(
            maxAssets: 9, // Allow multiple selection
            requestType: RequestType.image,
            textDelegate: const AssetPickerTextDelegate(),
          ),
        );

        if (assets != null && assets.isNotEmpty) {
          // Process each selected asset
          for (final asset in assets) {
            final File? file = await asset.file;
            if (file != null) {
              String imagePath = file.path;
              if (config?.onImagePicked != null) {
                String? updatedImagePath = await config?.onImagePicked!(
                  imagePath,
                );
                if (updatedImagePath != null) imagePath = updatedImagePath;
              }
              widget.onImageSelected(imagePath, '');
            }
          }
        }
      }
    } catch (e) {
      widget.onImageSelected('', e.toString());
    } finally {
      // To maintain the iOS native behavior of text field,
      // When the user taps on the gallery icon, and the text field has focus,
      // the keyboard should close.
      // We need to request focus again to open the keyboard.
      // This is not required for Android.
      // This is a workaround for the issue where the keyboard remain open and overlaps the text field.

      // https://github.com/SimformSolutionsPvtLtd/chatview/issues/266
      if (imageSource == ImageSource.gallery && Platform.isIOS && hasFocus) {
        widget.focusNode.requestFocus();
      }
    }
  }

  void _onChanged(String inputText) {
    debouncer.run(
      () {
        composingStatus.value = TypeWriterStatus.typed;
      },
      () {
        composingStatus.value = TypeWriterStatus.typing;
      },
    );
    _inputText.value = inputText;

    // Bubble raw text change to consumers if provided
    final onTextChanged = textFieldConfig?.onTextChanged;
    if (onTextChanged != null) {
      try {
        onTextChanged(inputText);
      } catch (_) {}
    }

    if (_inputText.value.trim().isNotEmpty) {
      // Hide options when user starts typing (Messenger-like)
      if (_showOptions.value) _showOptions.value = false;
    }
  }

  /// Build text field with mention support
  Widget _buildTextField(OutlineInputBorder outlineBorder) {
    // Check if controller is MentionTextController
    final isMentionController =
        widget.textEditingController is MentionTextController;

    if (isMentionController) {
      final mentionController =
          widget.textEditingController as MentionTextController;

      // Use Stack approach for mention styling
      return Stack(
        children: [
          // Actual text field
          TextField(
            focusNode: widget.focusNode,
            controller: widget.textEditingController,
            style: _getTextFieldStyle(mentionController),
            maxLines: textFieldConfig?.maxLines ?? 5,
            minLines: textFieldConfig?.minLines ?? 1,
            keyboardType: textFieldConfig?.textInputType,
            inputFormatters: [
              ...?textFieldConfig?.inputFormatters,
              mentionController.getMentionInputFormatter(),
            ],
            onChanged: _onChanged,
            enabled: textFieldConfig?.enabled,
            textCapitalization:
                textFieldConfig?.textCapitalization ??
                TextCapitalization.sentences,
            decoration: _getInputDecoration(outlineBorder),
          ),

          // Rich text overlay for mentions
          if (mentionController.entities.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  padding:
                      textFieldConfig?.contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: _buildStyledText(mentionController),
                ),
              ),
            ),
        ],
      );
    }

    // Regular text field for non-mention controllers
    return TextField(
      focusNode: widget.focusNode,
      controller: widget.textEditingController,
      style: textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white),
      maxLines: textFieldConfig?.maxLines ?? 5,
      minLines: textFieldConfig?.minLines ?? 1,
      keyboardType: textFieldConfig?.textInputType,
      inputFormatters: textFieldConfig?.inputFormatters,
      onChanged: _onChanged,
      enabled: textFieldConfig?.enabled,
      textCapitalization:
          textFieldConfig?.textCapitalization ?? TextCapitalization.sentences,
      decoration: _getInputDecoration(outlineBorder),
    );
  }

  TextStyle _getTextFieldStyle(MentionTextController mentionController) {
    final baseStyle =
        textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white);

    // Make text transparent where mentions exist so styled overlay shows through
    if (mentionController.entities.isNotEmpty) {
      return baseStyle.copyWith(color: Colors.transparent);
    }

    return baseStyle;
  }

  InputDecoration _getInputDecoration(OutlineInputBorder outlineBorder) {
    return InputDecoration(
      hintText:
          textFieldConfig?.hintText ?? PackageStrings.currentLocale.message,
      fillColor: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      filled: true,
      hintStyle:
          textFieldConfig?.hintStyle ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
            letterSpacing: 0.25,
          ),
      contentPadding:
          textFieldConfig?.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 6),
      border: outlineBorder,
      focusedBorder: outlineBorder,
      enabledBorder: outlineBorder,
      disabledBorder: outlineBorder,
    );
  }

  Widget _buildStyledText(MentionTextController mentionController) {
    final text = mentionController.text;

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build styled text span with blue mention chips
    final textSpan = mentionController.buildStyledTextSpan(
      defaultStyle:
          textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white),
    );

    return RichText(
      text: textSpan,
      maxLines: textFieldConfig?.maxLines ?? 5,
      overflow: TextOverflow.visible,
    );
  }
}
