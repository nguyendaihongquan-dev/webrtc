import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/video_call_model.dart';

/// Widget điều khiển video call
class VideoCallControls extends StatelessWidget {
  final VideoCallModel? call;
  final bool isIncoming;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onToggleAudio;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onEndCall;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const VideoCallControls({
    Key? key,
    this.call,
    this.isIncoming = false,
    this.onToggleVideo,
    this.onToggleAudio,
    this.onToggleSpeaker,
    this.onEndCall,
    this.onAccept,
    this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Call duration (if connected)
          if (call?.callState == VideoCallState.connected)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(call?.startTime),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          SizedBox(height: 24.h),

          // Control buttons
          if (isIncoming && call?.callState == VideoCallState.ringing)
            _buildIncomingControls()
          else
            _buildActiveControls(),
        ],
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Reject button
        _buildControlButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          onPressed: onReject,
          size: 60,
        ),

        // Accept button
        _buildControlButton(
          icon: Icons.videocam,
          backgroundColor: Colors.green,
          onPressed: onAccept,
          size: 60,
        ),
      ],
    );
  }

  Widget _buildActiveControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Video toggle
        _buildControlButton(
          icon: call?.isVideoEnabled == true
              ? Icons.videocam
              : Icons.videocam_off,
          backgroundColor: call?.isVideoEnabled == true
              ? Colors.white.withOpacity(0.2)
              : Colors.red,
          onPressed: onToggleVideo,
        ),

        // Audio toggle
        _buildControlButton(
          icon: call?.isAudioEnabled == true ? Icons.mic : Icons.mic_off,
          backgroundColor: call?.isAudioEnabled == true
              ? Colors.white.withOpacity(0.2)
              : Colors.red,
          onPressed: onToggleAudio,
        ),

        // Speaker toggle
        _buildControlButton(
          icon: call?.isSpeakerEnabled == true
              ? Icons.volume_up
              : Icons.volume_down,
          backgroundColor: call?.isSpeakerEnabled == true
              ? Colors.blue
              : Colors.white.withOpacity(0.2),
          onPressed: onToggleSpeaker,
        ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          onPressed: onEndCall,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback? onPressed,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: (size * 0.5).w),
      ),
    );
  }

  String _formatDuration(DateTime? startTime) {
    if (startTime == null) return '00:00';

    final duration = DateTime.now().difference(startTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
