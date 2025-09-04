/// Model cho video call state và participant information
class VideoCallModel {
  final String callId;
  final String channelId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final List<String> participants;
  final VideoCallType callType;
  final VideoCallState callState;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isIncoming;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isSpeakerEnabled;

  VideoCallModel({
    required this.callId,
    required this.channelId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.participants,
    required this.callType,
    required this.callState,
    required this.startTime,
    this.endTime,
    required this.isIncoming,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isSpeakerEnabled = false,
  });

  VideoCallModel copyWith({
    String? callId,
    String? channelId,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    List<String>? participants,
    VideoCallType? callType,
    VideoCallState? callState,
    DateTime? startTime,
    DateTime? endTime,
    bool? isIncoming,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    bool? isSpeakerEnabled,
  }) {
    return VideoCallModel(
      callId: callId ?? this.callId,
      channelId: channelId ?? this.channelId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      participants: participants ?? this.participants,
      callType: callType ?? this.callType,
      callState: callState ?? this.callState,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isIncoming: isIncoming ?? this.isIncoming,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isSpeakerEnabled: isSpeakerEnabled ?? this.isSpeakerEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'channelId': channelId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'participants': participants,
      'callType': callType.name,
      'callState': callState.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isIncoming': isIncoming,
      'isVideoEnabled': isVideoEnabled,
      'isAudioEnabled': isAudioEnabled,
      'isSpeakerEnabled': isSpeakerEnabled,
    };
  }

  factory VideoCallModel.fromJson(Map<String, dynamic> json) {
    return VideoCallModel(
      callId: json['callId'] as String,
      channelId: json['channelId'] as String,
      callerId: json['callerId'] as String,
      callerName: json['callerName'] as String,
      callerAvatar: json['callerAvatar'] as String?,
      participants: List<String>.from(json['participants'] as List),
      callType: VideoCallType.values.firstWhere(
        (e) => e.name == json['callType'],
        orElse: () => VideoCallType.p2p,
      ),
      callState: VideoCallState.values.firstWhere(
        (e) => e.name == json['callState'],
        orElse: () => VideoCallState.idle,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isIncoming: json['isIncoming'] as bool,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? true,
      isAudioEnabled: json['isAudioEnabled'] as bool? ?? true,
      isSpeakerEnabled: json['isSpeakerEnabled'] as bool? ?? false,
    );
  }
}

/// Loại video call
enum VideoCallType {
  p2p, // 1-1 call
  group, // Group call
}

/// Trạng thái video call
enum VideoCallState {
  idle, // Không có cuộc gọi
  calling, // Đang gọi
  ringing, // Đang đổ chuông
  connecting, // Đang kết nối
  connected, // Đã kết nối
  ended, // Cuộc gọi kết thúc
  rejected, // Cuộc gọi bị từ chối
  missed, // Cuộc gọi nhỡ
  failed, // Cuộc gọi thất bại
}

/// Thông tin participant trong cuộc gọi
class CallParticipant {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isConnected;
  final bool isLocalUser;

  CallParticipant({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isConnected = false,
    this.isLocalUser = false,
  });

  CallParticipant copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    bool? isVideoEnabled,
    bool? isAudioEnabled,
    bool? isConnected,
    bool? isLocalUser,
  }) {
    return CallParticipant(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isConnected: isConnected ?? this.isConnected,
      isLocalUser: isLocalUser ?? this.isLocalUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'isVideoEnabled': isVideoEnabled,
      'isAudioEnabled': isAudioEnabled,
      'isConnected': isConnected,
      'isLocalUser': isLocalUser,
    };
  }

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userAvatar: json['userAvatar'] as String?,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? true,
      isAudioEnabled: json['isAudioEnabled'] as bool? ?? true,
      isConnected: json['isConnected'] as bool? ?? false,
      isLocalUser: json['isLocalUser'] as bool? ?? false,
    );
  }
}

/// Cấu hình ICE servers
class ICEServerConfig {
  final String url;
  final String? username;
  final String? credential;
  final String? transport;

  ICEServerConfig({
    required this.url,
    this.username,
    this.credential,
    this.transport,
  });

  Map<String, dynamic> toJson() {
    return {
      'urls': url,
      if (username != null) 'username': username,
      if (credential != null) 'credential': credential,
    };
  }
}

/// Cấu hình video call
class VideoCallConfig {
  static List<ICEServerConfig> get p2pIceServers => [
    ICEServerConfig(
      url: 'turn:103.214.143.172:3478?transport=udp',
      username: 'turn_user_admin',
      credential: '24751b84c32a9ab53089cf',
    ),
    ICEServerConfig(
      url: 'turn:103.214.143.172:3478?transport=tcp',
      username: 'turn_user_admin',
      credential: '24751b84c32a9ab53089cf',
    ),
  ];

  static List<ICEServerConfig> get groupIceServers => [
    ICEServerConfig(url: 'stun:stun1.l.google.com:19302'),
    ICEServerConfig(url: 'stun:stun2.l.google.com:19302'),
    ICEServerConfig(url: 'stun:stunserver.org'),
    ICEServerConfig(
      url: 'turn:175.27.245.108:3478?transport=udp',
      username: 'user',
      credential: 'passwd',
    ),
  ];

  static List<ICEServerConfig> getIceServers(VideoCallType callType) {
    return callType == VideoCallType.p2p ? p2pIceServers : groupIceServers;
  }
}
