import '../../utils/constants/constants.dart';
import '../../values/enumeration.dart';
import '../../values/typedefs.dart';

class ReceiptsWidgetConfig {
  const ReceiptsWidgetConfig({
    this.receiptsBuilder,
    this.lastSeenAgoBuilder,
    this.showReceiptsIn = ShowReceiptsIn.lastMessage,
  });

  /// The builder that builds widget that right next to the senders message bubble.
  /// Right now it's implemented to show animation only at the last message just
  /// like instagram.
  /// By default [sendMessageAnimationBuilder]
  final ReceiptBuilder? receiptsBuilder;

  /// Just like Instagram messages receipts are displayed at the bottom of last
  /// message. If in case you want to modify it using your custom widget you can
  /// utilize this function.
  final LastSeenAgoBuilder? lastSeenAgoBuilder;

  /// Whether to show receipts in all messages or not defaults to [ShowReceiptsIn.lastMessage]
  final ShowReceiptsIn showReceiptsIn;
}
