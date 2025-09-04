import 'dart:async';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_call_model.dart';
import '../utils/logger.dart';

/// Service quản lý video call với WebRTC
class VideoCallService {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Call state
  VideoCallModel? _currentCall;
  final List<CallParticipant> _participants = [];

  // Event streams
  final StreamController<VideoCallModel> _callStateController =
      StreamController<VideoCallModel>.broadcast();
  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();
  final StreamController<CallParticipant> _participantController =
      StreamController<CallParticipant>.broadcast();

  // Getters
  VideoCallModel? get currentCall => _currentCall;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  Stream<VideoCallModel> get callStateStream => _callStateController.stream;
  Stream<MediaStream> get remoteStreamStream => _remoteStreamController.stream;
  Stream<CallParticipant> get participantStream =>
      _participantController.stream;

  /// Khởi tạo service
  Future<bool> initialize() async {
    try {
      Logger.service('VideoCallService', 'Initializing...');

      // Request permissions
      final permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        Logger.error('Permissions not granted');
        return false;
      }

      Logger.service('VideoCallService', 'Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to initialize', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Yêu cầu quyền camera và microphone
  Future<bool> _requestPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();

      return cameraStatus.isGranted && microphoneStatus.isGranted;
    } catch (e) {
      Logger.error('Failed to request permissions', error: e);
      return false;
    }
  }

  /// Bắt đầu cuộc gọi video
  Future<bool> startCall({
    required String channelId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required List<String> participants,
    required VideoCallType callType,
  }) async {
    try {
      Logger.service('VideoCallService', 'Starting call to $channelId');

      // Tạo call ID
      final callId = _generateCallId();

      // Tạo call model
      _currentCall = VideoCallModel(
        callId: callId,
        channelId: channelId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        participants: participants,
        callType: callType,
        callState: VideoCallState.calling,
        startTime: DateTime.now(),
        isIncoming: false,
      );

      // Khởi tạo local stream
      await _initializeLocalStream();

      // Tạo peer connection
      await _createPeerConnection(callType);

      // Cập nhật state
      _updateCallState(VideoCallState.calling);

      Logger.service('VideoCallService', 'Call started successfully');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to start call', error: e, stackTrace: stackTrace);
      _updateCallState(VideoCallState.failed);
      return false;
    }
  }

  /// Chấp nhận cuộc gọi đến
  Future<bool> acceptCall() async {
    try {
      if (_currentCall == null) return false;

      Logger.service(
        'VideoCallService',
        'Accepting call ${_currentCall!.callId}',
      );

      // Khởi tạo local stream
      await _initializeLocalStream();

      // Tạo peer connection
      await _createPeerConnection(_currentCall!.callType);

      // Cập nhật state
      _updateCallState(VideoCallState.connecting);

      Logger.service('VideoCallService', 'Call accepted successfully');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to accept call', error: e, stackTrace: stackTrace);
      _updateCallState(VideoCallState.failed);
      return false;
    }
  }

  /// Từ chối cuộc gọi
  Future<void> rejectCall() async {
    try {
      if (_currentCall == null) return;

      Logger.service(
        'VideoCallService',
        'Rejecting call ${_currentCall!.callId}',
      );

      _updateCallState(VideoCallState.rejected);
      await _cleanup();
    } catch (e, stackTrace) {
      Logger.error('Failed to reject call', error: e, stackTrace: stackTrace);
    }
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall() async {
    try {
      if (_currentCall == null) return;

      Logger.service('VideoCallService', 'Ending call ${_currentCall!.callId}');

      _updateCallState(VideoCallState.ended);
      await _cleanup();
    } catch (e, stackTrace) {
      Logger.error('Failed to end call', error: e, stackTrace: stackTrace);
    }
  }

  /// Bật/tắt video
  Future<void> toggleVideo() async {
    try {
      if (_localStream == null) return;

      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = !videoTracks.first.enabled;
        videoTracks.first.enabled = enabled;

        if (_currentCall != null) {
          _currentCall = _currentCall!.copyWith(isVideoEnabled: enabled);
          _callStateController.add(_currentCall!);
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to toggle video', error: e, stackTrace: stackTrace);
    }
  }

  /// Bật/tắt audio
  Future<void> toggleAudio() async {
    try {
      if (_localStream == null) return;

      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = !audioTracks.first.enabled;
        audioTracks.first.enabled = enabled;

        if (_currentCall != null) {
          _currentCall = _currentCall!.copyWith(isAudioEnabled: enabled);
          _callStateController.add(_currentCall!);
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to toggle audio', error: e, stackTrace: stackTrace);
    }
  }

  /// Bật/tắt speaker
  Future<void> toggleSpeaker() async {
    try {
      if (_currentCall == null) return;

      final enabled = !_currentCall!.isSpeakerEnabled;
      _currentCall = _currentCall!.copyWith(isSpeakerEnabled: enabled);
      _callStateController.add(_currentCall!);

      // TODO: Implement speaker toggle logic
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to toggle speaker',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Khởi tạo local media stream
  Future<void> _initializeLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'min': 640, 'ideal': 1280, 'max': 1920},
          'height': {'min': 480, 'ideal': 720, 'max': 1080},
        },
      });

      Logger.service('VideoCallService', 'Local stream initialized');
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to initialize local stream',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Tạo peer connection
  Future<void> _createPeerConnection(VideoCallType callType) async {
    try {
      final iceServers = VideoCallConfig.getIceServers(
        callType,
      ).map((server) => server.toJson()).toList();

      final configuration = <String, dynamic>{
        'iceServers': iceServers,
        'iceCandidatePoolSize': 10,
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add local stream
      if (_localStream != null) {
        await _peerConnection!.addStream(_localStream!);
      }

      // Set up event handlers
      _peerConnection!.onIceCandidate = _onIceCandidate;
      _peerConnection!.onAddStream = _onAddStream;
      _peerConnection!.onConnectionState = _onConnectionState;
      _peerConnection!.onIceConnectionState = _onIceConnectionState;

      Logger.service('VideoCallService', 'Peer connection created');
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to create peer connection',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Xử lý ICE candidate
  void _onIceCandidate(RTCIceCandidate candidate) {
    Logger.debug('ICE candidate: ${candidate.candidate}');
    // TODO: Send ICE candidate to remote peer via signaling
  }

  /// Xử lý remote stream
  void _onAddStream(MediaStream stream) {
    Logger.service('VideoCallService', 'Remote stream added');
    _remoteStream = stream;
    _remoteStreamController.add(stream);
  }

  /// Xử lý connection state
  void _onConnectionState(RTCPeerConnectionState state) {
    Logger.debug('Connection state: $state');

    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _updateCallState(VideoCallState.connected);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _updateCallState(VideoCallState.failed);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _updateCallState(VideoCallState.ended);
        break;
      default:
        break;
    }
  }

  /// Xử lý ICE connection state
  void _onIceConnectionState(RTCIceConnectionState state) {
    Logger.debug('ICE connection state: $state');
  }

  /// Cập nhật call state
  void _updateCallState(VideoCallState state) {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(callState: state);
      _callStateController.add(_currentCall!);
    }
  }

  /// Tạo call ID ngẫu nhiên
  String _generateCallId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    return 'call_${timestamp}_$randomNum';
  }

  /// Dọn dẹp resources
  Future<void> _cleanup() async {
    try {
      if (_localStream != null) {
        await _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      _participants.clear();
      _currentCall = null;

      Logger.service('VideoCallService', 'Cleanup completed');
    } catch (e, stackTrace) {
      Logger.error('Failed to cleanup', error: e, stackTrace: stackTrace);
    }
  }

  /// Dispose service
  void dispose() {
    _cleanup();
    _callStateController.close();
    _remoteStreamController.close();
    _participantController.close();
  }
}
