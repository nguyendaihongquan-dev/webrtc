import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_call_model.dart';
import '../utils/logger.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';

/// Service quản lý video call với WebRTC
class VideoCallService {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

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

  /// Khởi tạo thông tin cuộc gọi đến (trước khi accept)
  void beginIncomingCall({
    required String channelId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required List<String> participants,
    required VideoCallType callType,
  }) {
    _currentCall = VideoCallModel(
      callId: _generateCallId(),
      channelId: channelId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      participants: participants,
      callType: callType,
      callState: VideoCallState.ringing,
      startTime: DateTime.now(),
      isIncoming: true,
    );
    _callStateController.add(_currentCall!);
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

      // GỬI RTC INVITE (signaling tạm) qua kênh chat để bên kia tự mở UI
      try {
        final payload = {
          'callId': callId,
          'channelId': channelId,
          'callerId': callerId,
          'callerName': callerName,
          'callerAvatar': callerAvatar,
          'participants': participants,
          'callType': callType == VideoCallType.group ? 'group' : 'p2p',
        };

        // Gửi text message qua WuKong để máy bên kia nhận và tự mở UI
        final text = '__RTC_INVITE__|${jsonEncode(payload)}';
        final content = WKTextContent(text);
        final channelType = callType == VideoCallType.group
            ? WKChannelType.group
            : WKChannelType.personal;
        final channel = WKChannel(channelId, channelType);
        WKIM.shared.messageManager.sendMessage(content, channel);
        Logger.service('VideoCallService', 'RTC INVITE sent to $channelId');
      } catch (_) {}

      // Cập nhật state
      _updateCallState(VideoCallState.calling);

      // Tạo offer và gửi đi để bắt đầu đàm phán SDP
      await _createAndSendOffer(channelId, callType);

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
        // Explicitly use Unified Plan semantics (required on modern Android)
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add local tracks (Unified Plan: use addTrack instead of addStream)
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Set up event handlers
      _peerConnection!.onIceCandidate = _onIceCandidate;
      // Unified Plan: listen on onTrack instead of onAddStream
      _peerConnection!.onTrack = _onTrack;
      _peerConnection!.onIceGatheringState = (state) {
        Logger.debug('ICE gathering state: $state');
      };
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
    try {
      if (_currentCall == null) return;
      final channelId = _currentCall!.channelId;
      final callType = _currentCall!.callType;
      final payload = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };
      final text = '__RTC_ICE__|${jsonEncode(payload)}';
      final content = WKTextContent(text);
      final channelType = callType == VideoCallType.group
          ? WKChannelType.group
          : WKChannelType.personal;
      final channel = WKChannel(channelId, channelType);
      WKIM.shared.messageManager.sendMessage(content, channel);
    } catch (_) {}
  }

  /// Unified Plan: nhận remote stream qua onTrack
  void _onTrack(RTCTrackEvent event) {
    try {
      Logger.service('VideoCallService', 'onTrack: kind=${event.track.kind}');
      final remote = event.streams.isNotEmpty ? event.streams.first : null;
      if (remote != null) {
        _remoteStream = remote;
        _remoteStreamController.add(remote);
        // Apply any pending remote ICE candidates queued before remote stream available
        for (final c in _pendingRemoteCandidates) {
          _peerConnection?.addCandidate(c);
        }
        _pendingRemoteCandidates.clear();
      }
    } catch (e, st) {
      Logger.error('onTrack error', error: e, stackTrace: st);
    }
  }

  /// Tạo offer, setLocal, gửi qua WuKong
  Future<void> _createAndSendOffer(
    String channelId,
    VideoCallType callType,
  ) async {
    try {
      if (_peerConnection == null) return;
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(offer);

      final payload = {'sdp': offer.sdp, 'type': offer.type};
      final text = '__RTC_OFFER__|${jsonEncode(payload)}';
      final content = WKTextContent(text);
      final channelType = callType == VideoCallType.group
          ? WKChannelType.group
          : WKChannelType.personal;
      final channel = WKChannel(channelId, channelType);
      WKIM.shared.messageManager.sendMessage(content, channel);
      Logger.service('VideoCallService', 'RTC OFFER sent');
    } catch (e, st) {
      Logger.error('Failed to create/send offer', error: e, stackTrace: st);
    }
  }

  /// Xử lý offer nhận được, tạo answer và gửi lại
  Future<void> handleRemoteOffer(String sdp, String type) async {
    try {
      if (_peerConnection == null) return;
      final desc = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(desc);
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(answer);

      if (_currentCall == null) return;
      final payload = {'sdp': answer.sdp, 'type': answer.type};
      final text = '__RTC_ANSWER__|${jsonEncode(payload)}';
      final content = WKTextContent(text);
      final channelType = _currentCall!.callType == VideoCallType.group
          ? WKChannelType.group
          : WKChannelType.personal;
      final channel = WKChannel(_currentCall!.channelId, channelType);
      WKIM.shared.messageManager.sendMessage(content, channel);
      Logger.service('VideoCallService', 'RTC ANSWER sent');
    } catch (e, st) {
      Logger.error(
        'Failed to handle offer / send answer',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Xử lý answer nhận được
  Future<void> handleRemoteAnswer(String sdp, String type) async {
    try {
      if (_peerConnection == null) return;
      final desc = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(desc);
      Logger.service('VideoCallService', 'Remote ANSWER set');
    } catch (e, st) {
      Logger.error('Failed to handle answer', error: e, stackTrace: st);
    }
  }

  /// Xử lý ICE candidate nhận được
  Future<void> handleRemoteIce(
    String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  ) async {
    try {
      final ice = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
      if (_peerConnection == null) {
        _pendingRemoteCandidates.add(ice);
        return;
      }
      await _peerConnection!.addCandidate(ice);
      Logger.service('VideoCallService', 'Remote ICE added');
    } catch (e, st) {
      Logger.error('Failed to handle remote ice', error: e, stackTrace: st);
    }
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
