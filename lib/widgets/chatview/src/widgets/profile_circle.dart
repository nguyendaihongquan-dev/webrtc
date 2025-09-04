import 'package:flutter/material.dart';
import 'package:chatview_utils/chatview_utils.dart';

// removed old ProfileImageWidget import; using NetworkAvatar
import '../../../common/network_avatar.dart';

class ProfileCircle extends StatelessWidget {
  const ProfileCircle({
    Key? key,
    required this.bottomPadding,
    this.imageUrl,
    this.displayName,
    this.profileCirclePadding,
    this.circleRadius,
    this.onTap,
    this.onLongPress,
    this.defaultAvatarImage = Constants.profileImage,
    this.assetImageErrorBuilder,
    this.networkImageErrorBuilder,
    this.imageType = ImageType.network,
    this.networkImageProgressIndicatorBuilder,
  }) : super(key: key);

  /// Allow users to give  default bottom padding according to user case.
  final double bottomPadding;

  /// Allow user to pass image url, asset image of user's profile.
  /// Or
  /// Allow user to pass image data of user's profile picture in base64.
  final String? imageUrl;

  /// Preferred display name for placeholder initial
  final String? displayName;

  /// Field to define image type [network, asset or base64]
  final ImageType? imageType;

  /// Allow user to set whole padding of profile circle view.
  final EdgeInsetsGeometry? profileCirclePadding;

  /// Allow user to set radius of circle avatar.
  final double? circleRadius;

  /// Allow user to do operation when user tap on profile circle.
  final VoidCallback? onTap;

  /// Allow user to do operation when user long press on profile circle.
  final VoidCallback? onLongPress;

  /// Field to set default avatar image if profile image link not provided
  final String defaultAvatarImage;

  /// Error builder to build error widget for asset image
  final AssetImageErrorBuilder? assetImageErrorBuilder;

  /// Error builder to build error widget for network image
  final NetworkImageErrorBuilder? networkImageErrorBuilder;

  /// Progress indicator builder for network image
  final NetworkImageProgressIndicatorBuilder?
  networkImageProgressIndicatorBuilder;

  @override
  Widget build(BuildContext context) {
    final double diameter = (circleRadius ?? 16) * 2;
    return Padding(
      padding:
          profileCirclePadding ??
          EdgeInsets.only(left: 6.0, right: 4, bottom: bottomPadding),
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        child: NetworkAvatar(
          imageUrl: imageUrl ?? '',
          displayName: displayName ?? '',
          size: diameter,
        ),
      ),
    );
  }
}
