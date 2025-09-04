import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/video_call_model.dart';
import '../services/video_call_service.dart';
import '../utils/logger.dart';

/// Provider quản lý state của video call
class VideoCallProvider extends ChangeNotifier {
  final VideoCallService _videoCallService = VideoCallService();

  VideoCallService get videoCallService => _videoCallService;

  // State variables
  VideoCallModel? _currentCall;
  List<CallParticipant> _participants = [];
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isInitialized = false;
  String? _errorMessage;

  // Stream subscriptions
  StreamSubscription<VideoCallModel>? _callStateSubscription;
  StreamSubscription<MediaStream>? _remoteStreamSubscription;
  StreamSubscription<CallParticipant>? _participantSubscription;

  // Getters
  VideoCallModel? get currentCall => _currentCall;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isInCall =>
      _currentCall != null &&
      _currentCall!.callState != VideoCallState.idle &&
      _currentCall!.callState != VideoCallState.ended;

  /// Khởi tạo provider
  Future<bool> initialize() async {
    try {
      Logger.service('VideoCallProvider', 'Initializing...');

      final success = await _videoCallService.initialize();
      if (!success) {
        _errorMessage = 'Không thể khởi tạo video call service';
        notifyListeners();
        return false;
      }

      // Subscribe to streams
      _callStateSubscription = _videoCallService.callStateStream.listen(
        _onCallStateChanged,
        onError: _onError,
      );

      _remoteStreamSubscription = _videoCallService.remoteStreamStream.listen(
        _onRemoteStreamChanged,
        onError: _onError,
      );

      _participantSubscription = _videoCallService.participantStream.listen(
        _onParticipantChanged,
        onError: _onError,
      );

      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();

      Logger.service('VideoCallProvider', 'Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi khởi tạo: ${e.toString()}';
      notifyListeners();
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
      if (!_isInitialized) {
        _errorMessage = 'Video call service chưa được khởi tạo';
        notifyListeners();
        return false;
      }

      Logger.service('VideoCallProvider', 'Starting call to $channelId');

      final success = await _videoCallService.startCall(
        channelId: channelId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        participants: participants,
        callType: callType,
      );

      if (!success) {
        _errorMessage = 'Không thể bắt đầu cuộc gọi';
        notifyListeners();
      }

      return success;
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi bắt đầu cuộc gọi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Chấp nhận cuộc gọi đến
  Future<bool> acceptCall() async {
    try {
      if (!_isInitialized || _currentCall == null) {
        _errorMessage = 'Không có cuộc gọi để chấp nhận';
        notifyListeners();
        return false;
      }

      Logger.service('VideoCallProvider', 'Accepting call');

      final success = await _videoCallService.acceptCall();
      if (!success) {
        _errorMessage = 'Không thể chấp nhận cuộc gọi';
        notifyListeners();
      }

      return success;
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi chấp nhận cuộc gọi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Từ chối cuộc gọi
  Future<void> rejectCall() async {
    try {
      if (!_isInitialized || _currentCall == null) return;

      Logger.service('VideoCallProvider', 'Rejecting call');
      await _videoCallService.rejectCall();
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi từ chối cuộc gọi: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Kết thúc cuộc gọi
  Future<void> endCall() async {
    try {
      if (!_isInitialized || _currentCall == null) return;

      Logger.service('VideoCallProvider', 'Ending call');
      await _videoCallService.endCall();
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi kết thúc cuộc gọi: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Bật/tắt video
  Future<void> toggleVideo() async {
    try {
      if (!_isInitialized) return;

      await _videoCallService.toggleVideo();
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi bật/tắt video: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Bật/tắt audio
  Future<void> toggleAudio() async {
    try {
      if (!_isInitialized) return;

      await _videoCallService.toggleAudio();
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi bật/tắt audio: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Bật/tắt speaker
  Future<void> toggleSpeaker() async {
    try {
      if (!_isInitialized) return;

      await _videoCallService.toggleSpeaker();
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      _errorMessage = 'Lỗi bật/tắt speaker: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Xử lý call state thay đổi
  void _onCallStateChanged(VideoCallModel call) {
    _currentCall = call;
    _errorMessage = null;
    notifyListeners();
  }

  /// Xử lý remote stream thay đổi
  void _onRemoteStreamChanged(MediaStream stream) {
    _remoteStream = stream;
    notifyListeners();
  }

  /// Xử lý participant thay đổi
  void _onParticipantChanged(CallParticipant participant) {
    final index = _participants.indexWhere(
      (p) => p.userId == participant.userId,
    );
    if (index >= 0) {
      _participants[index] = participant;
    } else {
      _participants.add(participant);
    }
    notifyListeners();
  }

  /// Xử lý lỗi
  void _onError(dynamic error) {
    Logger.error('VideoCallProvider', error: error);
    _errorMessage = 'Lỗi video call: ${error.toString()}';
    notifyListeners();
  }

  /// Lấy local stream từ service
  Future<MediaStream?> getLocalStream() async {
    try {
      if (!_isInitialized) return null;

      // TODO: Implement getting local stream from service
      return _localStream;
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Kiểm tra quyền camera và microphone
  Future<bool> checkPermissions() async {
    try {
      // TODO: Implement permission checking
      return true;
    } catch (e, stackTrace) {
      Logger.error('VideoCallProvider', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Xóa thông báo lỗi
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _participantSubscription?.cancel();
    _videoCallService.dispose();
    super.dispose();
  }
}
