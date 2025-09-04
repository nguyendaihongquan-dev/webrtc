import 'package:flutter/material.dart';

import '../../models/config_models/reply_suggestions_config.dart';

/// This widget for alternative of excessive amount of passing arguments
/// over widgets.
class SuggestionsConfigIW extends InheritedWidget {
  const SuggestionsConfigIW({
    super.key,
    required super.child,
    this.suggestionsConfig,
  });

  /// The [suggestionsConfig] is used to provide the configuration for suggestion reply
  final ReplySuggestionsConfig? suggestionsConfig;

  /// This is used to access the [suggestionsConfig] from the widget tree.
  static SuggestionsConfigIW? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SuggestionsConfigIW>();

  @override
  bool updateShouldNotify(covariant SuggestionsConfigIW oldWidget) => false;
}
