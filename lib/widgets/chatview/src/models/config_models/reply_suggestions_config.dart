import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

import '../../values/enumeration.dart';
import 'suggestion_list_config.dart';

/// Configuration for reply suggestions in a chat view.
class ReplySuggestionsConfig {
  const ReplySuggestionsConfig({
    this.listConfig,
    this.itemConfig,
    this.onTap,
    this.autoDismissOnSelection = true,
    this.suggestionItemType = SuggestionItemsType.scrollable,
    this.spaceBetweenSuggestionItemRow = 10,
  });

  /// Used to give configuration for suggestion item.
  final SuggestionItemConfig? itemConfig;

  /// Used to give configuration for suggestion list.
  final SuggestionListConfig? listConfig;

  /// Provides callback when user taps on suggestion item.
  final ValueSetter<SuggestionItemData>? onTap;

  /// If true, the suggestion popup will be dismissed automatically when a suggestion is selected.
  final bool autoDismissOnSelection;

  /// Defines the type of suggestion items, whether they are scrollable or not.
  final SuggestionItemsType suggestionItemType;

  /// Defines the space between each row of suggestion items.
  final double spaceBetweenSuggestionItemRow;
}
