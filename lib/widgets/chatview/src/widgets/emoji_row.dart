import 'package:flutter/material.dart';

import '../extensions/extensions.dart';
import '../utils/constants/constants.dart';
import 'emoji_picker_widget.dart';

class EmojiRow extends StatelessWidget {
  EmojiRow({Key? key, required this.onEmojiTap}) : super(key: key);

  /// Provides callback when user taps on emoji in reaction pop-up.
  final ValueSetter<String> onEmojiTap;

  /// These are default emojis.
  final List<String> _emojiUnicodes = [
    heart,
    faceWithTears,
    astonishedFace,
    disappointedFace,
    angryFace,
    thumbsUp,
  ];

  @override
  Widget build(BuildContext context) {
    final emojiConfig = context.chatListConfig.reactionPopupConfig?.emojiConfig;
    final emojiList = emojiConfig?.emojiList ?? _emojiUnicodes;
    final size = emojiConfig?.size;
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              emojiList.length,
              (index) => GestureDetector(
                onTap: () => onEmojiTap(emojiList[index]),
                child: Text(
                  emojiList[index],
                  style: TextStyle(fontSize: size ?? 28),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          constraints: const BoxConstraints(),
          icon: Icon(Icons.add, color: Colors.grey.shade600, size: size ?? 28),
          onPressed: () => _showBottomSheet(context),
        ),
      ],
    );
  }

  void _showBottomSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (newContext) => EmojiPickerWidget(
      emojiPickerSheetConfig: context.chatListConfig.emojiPickerSheetConfig,
      onSelected: (emoji) {
        Navigator.pop(newContext);
        onEmojiTap(emoji);
      },
    ),
  );
}
