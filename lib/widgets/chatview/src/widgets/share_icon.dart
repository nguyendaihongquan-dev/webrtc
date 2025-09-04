import 'package:flutter/material.dart';
import 'package:chatview_utils/chatview_utils.dart';

import '../models/config_models/image_message_configuration.dart';

class ShareIcon extends StatelessWidget {
  const ShareIcon({
    super.key,
    this.shareIconConfig,
    required this.imageUrl,
    this.message,
  });

  /// Provides configuration of share icon which is showed in image preview.
  final ShareIconConfiguration? shareIconConfig;

  /// Provides image url of image message.
  final String imageUrl;

  /// Provides message object for advanced callbacks.
  final Message? message;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        // Prioritize onMessagePressed if available
        if (shareIconConfig?.onMessagePressed != null && message != null) {
          shareIconConfig!.onMessagePressed!(message!);
        } else if (shareIconConfig?.onPressed != null) {
          shareIconConfig!.onPressed!(imageUrl);
        }
      },
      padding: shareIconConfig?.margin ?? const EdgeInsets.all(8.0),
      icon:
          shareIconConfig?.icon ??
          Container(
            alignment: Alignment.center,
            padding: shareIconConfig?.padding ?? const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  shareIconConfig?.defaultIconBackgroundColor ??
                  Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.send,
              color: shareIconConfig?.defaultIconColor ?? Colors.black,
              size: 16,
            ),
          ),
    );
  }
}
