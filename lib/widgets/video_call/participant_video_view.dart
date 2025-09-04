import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/video_call_model.dart';

/// Widget hiển thị video của một participant
class ParticipantVideoView extends StatelessWidget {
  final CallParticipant participant;
  final MediaStream? stream;

  const ParticipantVideoView({Key? key, required this.participant, this.stream})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: participant.isConnected ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Video stream or placeholder
            if (stream != null && participant.isVideoEnabled)
              RTCVideoView(
                RTCVideoRenderer()..srcObject = stream!,
                mirror: participant.isLocalUser,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[700],
                        child: participant.userAvatar != null
                            ? ClipOval(
                                child: Image.network(
                                  participant.userAvatar!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        participant.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

            // Status indicators
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  // Connection status
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: participant.isConnected
                          ? Colors.green
                          : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Audio status
                  Icon(
                    participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                    color: participant.isAudioEnabled
                        ? Colors.white
                        : Colors.red,
                    size: 16,
                  ),
                ],
              ),
            ),

            // Video status
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                participant.isVideoEnabled
                    ? Icons.videocam
                    : Icons.videocam_off,
                color: participant.isVideoEnabled ? Colors.white : Colors.red,
                size: 16,
              ),
            ),

            // Local user indicator
            if (participant.isLocalUser)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Bạn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
