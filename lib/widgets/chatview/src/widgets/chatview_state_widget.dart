import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

import '../extensions/extensions.dart';
import '../models/config_models/chat_view_states_configuration.dart';
import '../utils/package_strings.dart';
import '../values/enumeration.dart';

class ChatViewStateWidget extends StatelessWidget {
  const ChatViewStateWidget({
    Key? key,
    this.chatViewStateWidgetConfig,
    required this.chatViewState,
    this.onReloadButtonTap,
  }) : super(key: key);

  /// Provides configuration of chat view's different states such as text styles,
  /// widgets and etc.
  final ChatViewStateWidgetConfiguration? chatViewStateWidgetConfig;

  /// Provides current state of chat view.
  final ChatViewState chatViewState;

  /// Provides callback when user taps on reload button in error and no messages
  /// state.
  final VoidCallback? onReloadButtonTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          chatViewStateWidgetConfig?.widget ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                (chatViewStateWidgetConfig?.title.getChatViewStateTitle(
                  chatViewState,
                ))!,
                style:
                    chatViewStateWidgetConfig?.titleTextStyle ??
                    const TextStyle(fontSize: 22),
              ),
              if (chatViewStateWidgetConfig?.subTitle != null)
                Text(
                  (chatViewStateWidgetConfig?.subTitle)!,
                  style: chatViewStateWidgetConfig?.subTitleTextStyle,
                ),
              if (chatViewState.isLoading)
                CircularProgressIndicator(
                  color: chatViewStateWidgetConfig?.loadingIndicatorColor,
                ),
              if (chatViewStateWidgetConfig?.imageWidget != null)
                (chatViewStateWidgetConfig?.imageWidget)!,
              if (chatViewStateWidgetConfig?.reloadButton != null)
                (chatViewStateWidgetConfig?.reloadButton)!,
              if (chatViewStateWidgetConfig != null &&
                  (chatViewStateWidgetConfig?.showDefaultReloadButton)! &&
                  chatViewStateWidgetConfig?.reloadButton == null &&
                  (chatViewState.isError || chatViewState.noMessages)) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onReloadButtonTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        chatViewStateWidgetConfig?.reloadButtonColor ??
                        const Color(0xffEE5366),
                  ),
                  child: Text(PackageStrings.currentLocale.reload),
                ),
              ],
            ],
          ),
    );
  }
}
