import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/video_call_model.dart';

/// Widget nút gọi video trong chat interface
class VideoCallButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final VideoCallType callType;
  final String? tooltip;

  const VideoCallButton({
    Key? key,
    this.onPressed,
    this.isEnabled = true,
    this.callType = VideoCallType.p2p,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? _getDefaultTooltip(),
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(
          callType == VideoCallType.group ? Icons.video_call : Icons.videocam,
          color: isEnabled ? Colors.blue : Colors.grey,
          size: 24.sp,
        ),
        constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
        padding: EdgeInsets.all(8.w),
      ),
    );
  }

  String _getDefaultTooltip() {
    return callType == VideoCallType.group ? 'Gọi video nhóm' : 'Gọi video';
  }
}

/// Widget nút gọi audio (voice call)
class AudioCallButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isEnabled;
  final String? tooltip;

  const AudioCallButton({
    Key? key,
    this.onPressed,
    this.isEnabled = true,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'Gọi thoại',
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(
          Icons.call,
          color: isEnabled ? Colors.green : Colors.grey,
          size: 24.sp,
        ),
        constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.h),
        padding: EdgeInsets.all(8.w),
      ),
    );
  }
}

/// Widget chứa các nút gọi trong chat header
class CallButtonsRow extends StatelessWidget {
  final VoidCallback? onVideoCall;
  final VoidCallback? onAudioCall;
  final bool isVideoCallEnabled;
  final bool isAudioCallEnabled;
  final VideoCallType callType;

  const CallButtonsRow({
    Key? key,
    this.onVideoCall,
    this.onAudioCall,
    this.isVideoCallEnabled = true,
    this.isAudioCallEnabled = true,
    this.callType = VideoCallType.p2p,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio call button
        AudioCallButton(
          onPressed: isAudioCallEnabled ? onAudioCall : null,
          isEnabled: isAudioCallEnabled,
        ),

        // Video call button
        VideoCallButton(
          onPressed: isVideoCallEnabled ? onVideoCall : null,
          isEnabled: isVideoCallEnabled,
          callType: callType,
        ),
      ],
    );
  }
}
