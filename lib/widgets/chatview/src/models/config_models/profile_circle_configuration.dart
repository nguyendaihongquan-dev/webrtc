import 'package:chatview_utils/chatview_utils.dart';
import 'package:flutter/material.dart';

class ProfileCircleConfiguration {
  const ProfileCircleConfiguration({
    this.onAvatarTap,
    this.padding,
    this.profileImageUrl,
    this.bottomPadding,
    this.circleRadius,
    this.onAvatarLongPress,
    this.imageType = ImageType.network,
    this.defaultAvatarImage = Constants.profileImage,
    this.networkImageErrorBuilder,
    this.assetImageErrorBuilder,
    this.networkImageProgressIndicatorBuilder,
  });

  /// Used to give padding to profile circle.
  final EdgeInsetsGeometry? padding;

  /// Provides image url as network or asset of user.
  /// Or
  /// Provides image data of user in base64
  final String? profileImageUrl;

  /// Used for give bottom padding to profile circle
  final double? bottomPadding;

  /// Used for give circle radius to profile circle
  final double? circleRadius;

  /// Provides callback when user tap on profile circle.
  final ValueSetter<ChatUser>? onAvatarTap;

  /// Provides callback when user long press on profile circle.
  final ValueSetter<ChatUser>? onAvatarLongPress;

  /// Field to define image type [network, asset or base64]
  final ImageType imageType;

  /// Field to set default avatar image if profile image link not provided
  final String defaultAvatarImage;

  /// Error builder to build error widget for asset image
  final AssetImageErrorBuilder? assetImageErrorBuilder;

  /// Error builder to build error widget for network image
  final NetworkImageErrorBuilder? networkImageErrorBuilder;

  /// Progress indicator builder for network image
  final NetworkImageProgressIndicatorBuilder?
  networkImageProgressIndicatorBuilder;
}
