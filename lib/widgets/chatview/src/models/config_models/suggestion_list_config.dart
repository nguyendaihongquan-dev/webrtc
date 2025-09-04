import 'package:flutter/material.dart';

import '../../values/enumeration.dart';

class SuggestionListConfig {
  const SuggestionListConfig({
    this.decoration,
    this.padding,
    this.margin,
    this.axisAlignment = SuggestionListAlignment.right,
    this.itemSeparatorWidth = 8,
  });

  /// Provides decoration for the suggestion list
  final BoxDecoration? decoration;

  /// Padding for the suggestion list
  final EdgeInsets? padding;

  /// Margin for the suggestion list
  final EdgeInsets? margin;

  /// Separator width of the item in the suggestion list
  final double itemSeparatorWidth;

  /// Alignment of the suggestion list items
  final SuggestionListAlignment axisAlignment;
}
