// Different types Message of ChatView

import 'package:flutter/material.dart';
import 'package:chatview_utils/chatview_utils.dart';

enum ShowReceiptsIn { all, lastMessage }

enum SuggestionListAlignment {
  left(Alignment.bottomLeft),
  center(Alignment.bottomCenter),
  right(Alignment.bottomRight);

  const SuggestionListAlignment(this.alignment);

  final Alignment alignment;
}

extension ChatViewStateExtension on ChatViewState {
  bool get hasMessages => this == ChatViewState.hasMessages;

  bool get isLoading => this == ChatViewState.loading;

  bool get isError => this == ChatViewState.error;

  bool get noMessages => this == ChatViewState.noData;
}

enum GroupedListOrder { asc, desc }

extension GroupedListOrderExtension on GroupedListOrder {
  bool get isAsc => this == GroupedListOrder.asc;

  bool get isDesc => this == GroupedListOrder.desc;
}

enum ScrollButtonAlignment {
  left(Alignment.bottomLeft),
  center(Alignment.bottomCenter),
  right(Alignment.bottomRight);

  const ScrollButtonAlignment(this.alignment);

  final Alignment alignment;
}

enum SuggestionItemsType {
  scrollable,
  multiline;

  bool get isScrollType => this == SuggestionItemsType.scrollable;

  bool get isMultilineType => this == SuggestionItemsType.multiline;
}
