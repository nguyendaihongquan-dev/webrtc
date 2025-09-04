import '../../values/typedefs.dart';
import '../models.dart';

class MessageConfiguration {
  const MessageConfiguration({
    this.imageMessageConfig,
    this.messageReactionConfig,
    this.emojiMessageConfig,
    this.customMessageBuilder,
    this.voiceMessageConfig,
    this.customMessageReplyViewBuilder,
  });

  /// Provides configuration of image message appearance.
  final ImageMessageConfiguration? imageMessageConfig;

  /// Provides configuration of image message appearance.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Provides configuration of emoji messages appearance.
  final EmojiMessageConfiguration? emojiMessageConfig;

  /// Provides builder to create view for custom messages.
  final CustomMessageBuilder? customMessageBuilder;

  /// Configurations for voice message bubble
  final VoiceMessageConfiguration? voiceMessageConfig;

  /// To customize reply view for custom message type
  final CustomMessageReplyViewBuilder? customMessageReplyViewBuilder;
}
