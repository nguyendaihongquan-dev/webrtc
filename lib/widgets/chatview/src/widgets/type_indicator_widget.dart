import 'dart:math';

import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../extensions/extensions.dart';
import '../models/chat_bubble.dart';
import '../models/config_models/profile_circle_configuration.dart';
import '../models/config_models/type_indicator_configuration.dart';
import '../utils/constants/constants.dart';
import 'profile_circle.dart';
import 'package:qgim_client_flutter/providers/chat_provider.dart';
import 'package:qgim_client_flutter/config/constants.dart' as app_config;

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    Key? key,
    this.showIndicator = false,
    this.chatBubbleConfig,
    this.typeIndicatorConfig,
  }) : super(key: key);

  /// Allow user to turn on/off typing indicator.
  final bool showIndicator;

  /// Provides configurations related to chat bubble such as padding, margin, max
  /// width etc.
  final ChatBubble? chatBubbleConfig;

  /// Provides configurations related to typing indicator appearance.
  final TypeIndicatorConfiguration? typeIndicatorConfig;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _appearanceController;

  late Animation<double> _indicatorSpaceAnimation;

  late Animation<double> _largeBubbleAnimation;

  late AnimationController _repeatingController;
  final List<Interval> _dotIntervals = const [
    Interval(0.25, 0.8),
    Interval(0.35, 0.9),
    Interval(0.45, 1.0),
  ];

  final List<AnimationController> _jumpControllers = [];
  final List<Animation> _jumpAnimations = [];

  ProfileCircleConfiguration? profileCircleConfiguration;

  // Cache typing user info when indicator starts showing
  String _cachedTypingUserId = '';
  String _cachedTypingUserName = '';

  ChatBubble? get chatBubbleConfig => widget.chatBubbleConfig;

  double get indicatorSize => widget.typeIndicatorConfig?.indicatorSize ?? 10;

  double get indicatorSpacing =>
      widget.typeIndicatorConfig?.indicatorSpacing ?? 4;

  Color? get flashingCircleDarkColor =>
      widget.typeIndicatorConfig?.flashingCircleDarkColor ??
      const Color(0xFF939497);

  Color? get flashingCircleBrightColor =>
      widget.typeIndicatorConfig?.flashingCircleBrightColor ??
      const Color(0xFFadacb0);

  @override
  void initState() {
    super.initState();
    if (mounted) _initializeAnimationController();
  }

  void _initializeAnimationController() {
    _appearanceController = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });

    _indicatorSpaceAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ).drive(Tween<double>(begin: 0.0, end: 60.0));

    _largeBubbleAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _repeatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    for (int i = 0; i < 3; i++) {
      _jumpControllers.add(
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
          reverseDuration: const Duration(milliseconds: 500),
        ),
      );
      _jumpAnimations.add(
        CurvedAnimation(
          parent: _jumpControllers[i],
          curve: Interval((0.2 * i), 0.7, curve: Curves.easeOutSine),
          reverseCurve: Interval((0.2 * i), 0.7, curve: Curves.easeOut),
        ).drive(Tween<double>(begin: 0, end: 10)),
      );
    }

    if (widget.showIndicator) {
      _showIndicator();
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showIndicator != oldWidget.showIndicator) {
      if (widget.showIndicator) {
        _showIndicator();
      } else {
        _hideIndicator();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      profileCircleConfiguration = chatViewIW!.profileCircleConfiguration;
    }
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    _repeatingController.dispose();
    for (var element in _jumpControllers) {
      element.dispose();
    }
    super.dispose();
  }

  void _showIndicator() {
    _appearanceController
      ..duration = const Duration(milliseconds: 750)
      ..forward();
    _repeatingController.repeat();
    for (int i = 0; i < 3; i++) {
      _jumpControllers[i].repeat(reverse: true);
    }
  }

  void _hideIndicator() {
    _appearanceController
      ..duration = const Duration(milliseconds: 150)
      ..reverse();
    _repeatingController.stop();
    for (int i = 0; i < 3; i++) {
      _jumpControllers[i].stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _indicatorSpaceAnimation,
      builder: (context, child) {
        return SizedBox(height: _indicatorSpaceAnimation.value, child: child);
      },
      child: Stack(
        children: [
          _buildAnimatedBubble(
            animation: _largeBubbleAnimation,
            left: 5,
            bottom: 12,
            bubble: _buildStatusBubble(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBubble({
    required Animation<double> animation,
    required double left,
    required double bottom,
    required Widget bubble,
  }) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: animation.value,
            alignment: Alignment.centerLeft,
            child: child,
          );
        },
        child: Row(
          children: [
            Builder(
              builder: (context) {
                if (widget.showIndicator) {
                  final chatProvider = Provider.of<ChatProvider>(
                    context,
                    listen: false,
                  );
                  if (chatProvider.typingUserId.isNotEmpty) {
                    _cachedTypingUserId = chatProvider.typingUserId;
                    _cachedTypingUserName = chatProvider.typingUserName;
                  }
                }

                final String configAvatarUrl =
                    widget.typeIndicatorConfig?.typingUserAvatarUrl ?? '';
                final String avatarUrl = configAvatarUrl.isNotEmpty
                    ? configAvatarUrl
                    : (_cachedTypingUserId.isNotEmpty
                          ? app_config.WKApiConfig.getAvatarUrl(
                              _cachedTypingUserId,
                            )
                          : '');

                final String configDisplayName =
                    widget.typeIndicatorConfig?.typingUserDisplayName ?? '';
                final String displayName = configDisplayName.trim().isNotEmpty
                    ? configDisplayName
                    : _cachedTypingUserName;

                return ProfileCircle(
                  bottomPadding: 0,
                  imageUrl: avatarUrl,
                  displayName: displayName,
                  imageType: profileCircleConfiguration?.imageType,
                  assetImageErrorBuilder:
                      profileCircleConfiguration?.assetImageErrorBuilder,
                  networkImageErrorBuilder:
                      profileCircleConfiguration?.networkImageErrorBuilder,
                  defaultAvatarImage:
                      profileCircleConfiguration?.defaultAvatarImage ??
                      Constants.profileImage,
                  networkImageProgressIndicatorBuilder:
                      profileCircleConfiguration
                          ?.networkImageProgressIndicatorBuilder,
                );
              },
            ),
            bubble,
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBubble() {
    return Container(
      padding:
          chatBubbleConfig?.padding ??
          const EdgeInsets.fromLTRB(
            leftPadding3,
            0,
            leftPadding3,
            leftPadding3,
          ),
      margin: chatBubbleConfig?.margin ?? const EdgeInsets.fromLTRB(5, 0, 6, 2),
      decoration: BoxDecoration(
        borderRadius:
            chatBubbleConfig?.borderRadius ??
            BorderRadius.circular(replyBorderRadius2),
        color: chatBubbleConfig?.color ?? Colors.grey.shade500,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            _bubbleJumpAnimation(2, 0),
            _bubbleJumpAnimation(1, 1),
            _bubbleJumpAnimation(0, 2),
          ],
        ),
      ),
    );
  }

  Widget _bubbleJumpAnimation(int value, int index) {
    return AnimatedBuilder(
      animation: _jumpAnimations[value],
      builder: (context, child) {
        final circleFlashPercent = _dotIntervals[index].transform(
          _repeatingController.value,
        );
        final circleColorPercent = sin(pi * circleFlashPercent);
        return Transform.translate(
          offset: Offset(0, _jumpAnimations[value].value),
          child: Container(
            width: indicatorSize,
            height: indicatorSize,
            margin: EdgeInsets.symmetric(horizontal: indicatorSpacing),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                flashingCircleDarkColor,
                flashingCircleBrightColor,
                circleColorPercent,
              ),
            ),
          ),
        );
      },
    );
  }
}
