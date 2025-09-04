import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chatview_utils/chatview_utils.dart';

class ProfileImageWidget extends StatelessWidget {
  const ProfileImageWidget({
    super.key,
    this.imageUrl,
    this.defaultAvatarImage = Constants.profileImage,
    this.circleRadius,
    this.assetImageErrorBuilder,
    this.networkImageErrorBuilder,
    this.imageType = ImageType.network,
    required this.networkImageProgressIndicatorBuilder,
  });

  /// Allow user to set radius of circle avatar.
  final double? circleRadius;

  /// Allow user to pass image url of user's profile picture.
  final String? imageUrl;

  /// Flag to check whether image is network or asset
  final ImageType? imageType;

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
    final radius = (circleRadius ?? 20) * 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(circleRadius ?? 20),
      child: switch (imageType) {
        ImageType.asset when (imageUrl?.isNotEmpty ?? false) => Image.asset(
          imageUrl!,
          height: radius,
          width: radius,
          fit: BoxFit.cover,
          errorBuilder: assetImageErrorBuilder ?? _errorWidget,
        ),
        ImageType.network when (imageUrl?.isNotEmpty ?? false) =>
          CachedNetworkImage(
            imageUrl: imageUrl ?? defaultAvatarImage,
            height: radius,
            width: radius,
            fit: BoxFit.cover,
            progressIndicatorBuilder:
                networkImageProgressIndicatorBuilder == null
                ? null
                : (context, url, progress) =>
                      networkImageProgressIndicatorBuilder!.call(
                        context,
                        url,
                        CacheNetworkImageDownloadProgress(
                          progress.originalUrl,
                          progress.totalSize,
                          progress.downloaded,
                        ),
                      ),
            errorWidget: networkImageErrorBuilder ?? _networkImageErrorWidget,
          ),
        ImageType.base64 when (imageUrl?.isNotEmpty ?? false) => Image.memory(
          base64Decode(imageUrl!),
          height: radius,
          width: radius,
          fit: BoxFit.cover,
          errorBuilder: assetImageErrorBuilder ?? _errorWidget,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _networkImageErrorWidget(context, url, error) {
    return const Center(child: Icon(Icons.error_outline, size: 18));
  }

  Widget _errorWidget(context, error, stackTrace) {
    return const Center(child: Icon(Icons.error_outline, size: 18));
  }
}
