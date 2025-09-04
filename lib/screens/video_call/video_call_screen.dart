import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../models/video_call_model.dart';
import '../../providers/video_call_provider.dart';
import '../../widgets/video_call/video_call_controls.dart';
import '../../widgets/video_call/participant_video_view.dart';
import '../../widgets/video_call/call_info_header.dart';
// import '../../config/theme.dart';

/// Màn hình video call chính
class VideoCallScreen extends StatefulWidget {
  final String channelId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final List<String> participants;
  final VideoCallType callType;
  final bool isIncoming;

  const VideoCallScreen({
    Key? key,
    required this.channelId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.participants,
    required this.callType,
    this.isIncoming = false,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late VideoCallProvider _videoCallProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    _videoCallProvider = Provider.of<VideoCallProvider>(context, listen: false);

    if (!_videoCallProvider.isInitialized) {
      await _videoCallProvider.initialize();
    }

    if (widget.isIncoming) {
      // Cuộc gọi đến - chỉ hiển thị thông tin
      setState(() {
        _isInitialized = true;
      });
    } else {
      // Cuộc gọi đi - bắt đầu cuộc gọi
      final success = await _videoCallProvider.startCall(
        channelId: widget.channelId,
        callerId: widget.callerId,
        callerName: widget.callerName,
        callerAvatar: widget.callerAvatar,
        participants: widget.participants,
        callType: widget.callType,
      );

      if (success) {
        setState(() {
          _isInitialized = true;
        });
      } else {
        _showErrorDialog('Không thể bắt đầu cuộc gọi');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<VideoCallProvider>(
          builder: (context, provider, child) {
            if (!_isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            return Stack(
              children: [
                // Video views
                _buildVideoViews(provider),

                // Call info header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CallInfoHeader(
                    call: provider.currentCall,
                    isIncoming: widget.isIncoming,
                    onAccept: () async {
                      final success = await provider.acceptCall();
                      if (!success) {
                        _showErrorDialog('Không thể chấp nhận cuộc gọi');
                      }
                    },
                    onReject: () async {
                      await provider.rejectCall();
                      Navigator.of(context).pop();
                    },
                  ),
                ),

                // Call controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoCallControls(
                    call: provider.currentCall,
                    isIncoming: widget.isIncoming,
                    onToggleVideo: () => provider.toggleVideo(),
                    onToggleAudio: () => provider.toggleAudio(),
                    onToggleSpeaker: () => provider.toggleSpeaker(),
                    onEndCall: () async {
                      await provider.endCall();
                      Navigator.of(context).pop();
                    },
                    onAccept: () async {
                      final success = await provider.acceptCall();
                      if (!success) {
                        _showErrorDialog('Không thể chấp nhận cuộc gọi');
                      }
                    },
                    onReject: () async {
                      await provider.rejectCall();
                      Navigator.of(context).pop();
                    },
                  ),
                ),

                // Error message
                if (provider.errorMessage != null)
                  Positioned(
                    top: 100,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () => provider.clearError(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoViews(VideoCallProvider provider) {
    if (widget.callType == VideoCallType.p2p) {
      return _buildP2PVideoViews(provider);
    } else {
      return _buildGroupVideoViews(provider);
    }
  }

  Widget _buildP2PVideoViews(VideoCallProvider provider) {
    return Stack(
      children: [
        // Remote video (full screen)
        if (provider.remoteStream != null)
          RTCVideoView(
            RTCVideoRenderer()..srcObject = provider.remoteStream!,
            mirror: false,
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
                    radius: 60,
                    backgroundColor: Colors.grey[700],
                    child: widget.callerAvatar != null
                        ? ClipOval(
                            child: Image.network(
                              widget.callerAvatar!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getCallStateText(provider.currentCall?.callState),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Local video (picture-in-picture)
        if (provider.localStream != null)
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  RTCVideoRenderer()..srcObject = provider.localStream!,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupVideoViews(VideoCallProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: provider.participants.length + 1, // +1 for local user
        itemBuilder: (context, index) {
          if (index == 0) {
            // Local user
            return ParticipantVideoView(
              participant: CallParticipant(
                userId: 'local',
                userName: 'Bạn',
                isLocalUser: true,
                isVideoEnabled: provider.currentCall?.isVideoEnabled ?? true,
                isAudioEnabled: provider.currentCall?.isAudioEnabled ?? true,
                isConnected: true,
              ),
              stream: provider.localStream,
            );
          } else {
            // Remote participants
            final participant = provider.participants[index - 1];
            return ParticipantVideoView(
              participant: participant,
              stream: provider.remoteStream,
            );
          }
        },
      ),
    );
  }

  String _getCallStateText(VideoCallState? state) {
    switch (state) {
      case VideoCallState.calling:
        return 'Đang gọi...';
      case VideoCallState.ringing:
        return 'Đang đổ chuông...';
      case VideoCallState.connecting:
        return 'Đang kết nối...';
      case VideoCallState.connected:
        return 'Đã kết nối';
      case VideoCallState.ended:
        return 'Cuộc gọi kết thúc';
      case VideoCallState.rejected:
        return 'Cuộc gọi bị từ chối';
      case VideoCallState.missed:
        return 'Cuộc gọi nhỡ';
      case VideoCallState.failed:
        return 'Cuộc gọi thất bại';
      default:
        return '';
    }
  }
}
