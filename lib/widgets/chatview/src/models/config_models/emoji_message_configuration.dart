import 'package:flutter/material.dart';

class EmojiMessageConfiguration {
  const EmojiMessageConfiguration({this.padding, this.textStyle});

  /// Used for giving padding to emoji messages.
  final EdgeInsetsGeometry? padding;

  /// Used for giving text style to emoji messages.
  final TextStyle? textStyle;
}
