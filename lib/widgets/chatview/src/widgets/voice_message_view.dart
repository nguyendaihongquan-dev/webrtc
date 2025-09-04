import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview_utils/chatview_utils.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/constants.dart';
import '../models/chat_bubble.dart';
import '../models/config_models/message_reaction_configuration.dart';
import '../models/config_models/voice_message_configuration.dart';
import 'reaction_widget.dart';
import '../../../../utils/logger.dart';

class VoiceMessageView extends StatefulWidget {
  const VoiceMessageView({
    Key? key,
    required this.screenWidth,
    required this.message,
    required this.isMessageBySender,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.onMaxDuration,
    this.messageReactionConfig,
    this.config,
  }) : super(key: key);

  /// Provides configuration related to voice message.
  final VoiceMessageConfiguration? config;

  /// Allow user to set width of chat bubble.
  final double screenWidth;

  /// Provides message instance of chat.
  final Message message;
  final ValueSetter<int>? onMaxDuration;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  @override
  State<VoiceMessageView> createState() => _VoiceMessageViewState();
}

class _VoiceMessageViewState extends State<VoiceMessageView> {
  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;

  bool _isPrepared = false;

  final ValueNotifier<PlayerState> _playerState = ValueNotifier(
    PlayerState.stopped,
  );

  PlayerState get playerState => _playerState.value;

  PlayerWaveStyle playerWaveStyle = const PlayerWaveStyle(scaleFactor: 70);

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _initAndPrepare();
    playerStateSubscription = controller.onPlayerStateChanged.listen((state) {
      _playerState.value = state;
      Logger.ui(
        'VoiceMessageView',
        '🎧 PlayerState changed: $state (msgId=${widget.message.id})',
      );
    });
  }

  Future<void> _initAndPrepare() async {
    // Raw content from message
    String raw = widget.message.message;
    Logger.ui(
      'VoiceMessageView',
      '🎧 init prepare: raw="$raw" (msgId=${widget.message.id})',
    );

    // Determine if message points to a remote URL, a local file, or a server-relative path
    String path = raw;

    // Normalize file:// scheme
    if (path.startsWith('file://')) {
      path = path.replaceFirst('file://', '');
      Logger.ui('VoiceMessageView', '🎧 normalized file scheme -> $path');
    }

    final bool isHttp = path.startsWith('http') || path.startsWith('HTTP');
    final bool isAbsoluteLocalPath =
        path.startsWith('/') &&
        (path.contains('/data/') ||
            path.contains('/storage/') ||
            path.contains('/sdcard') ||
            File(path).existsSync());

    Logger.ui(
      'VoiceMessageView',
      '🎧 classify: isHttp=$isHttp isAbsLocal=$isAbsoluteLocalPath startsWithSlash=${path.startsWith('/')}',
    );

    if (!isHttp) {
      if (isAbsoluteLocalPath) {
        final exists = File(path).existsSync();
        Logger.ui(
          'VoiceMessageView',
          '🎧 local abs path: exists=$exists path=$path',
        );
      } else {
        // Treat any non-http, non-local-absolute path as server path (with or without leading '/')
        final resolved = WKApiConfig.getShowUrl(path);
        Logger.ui(
          'VoiceMessageView',
          '🎧 server path -> $resolved from $path (base=${WKApiConfig.baseUrl})',
        );
        path = resolved;
      }
    }

    Logger.ui('VoiceMessageView', '🎧 final path to prepare: $path');

    // iOS: If AMR, transcode to M4A before playback
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        path.toLowerCase().endsWith('.amr')) {
      Logger.ui(
        'VoiceMessageView',
        '🔁 AMR detected on iOS, converting to M4A',
      );

      // Ensure we have the local AMR file first
      String amrPath = path;
      if (amrPath.startsWith('http') || amrPath.startsWith('HTTP')) {
        final local = await _downloadVoiceToCache(amrPath);
        if (local == null) {
          Logger.error(
            'VoiceMessageView: ❌ failed to download AMR for transcoding',
          );
          _isPrepared = false;
          return;
        }
        amrPath = local;
      }

      final m4aPath = await _transcodeAmrToM4a(amrPath);
      if (m4aPath == null) {
        Logger.error('VoiceMessageView: ❌ AMR→M4A transcode failed');
        _isPrepared = false;
        return;
      }
      path = m4aPath;
      Logger.ui('VoiceMessageView', '✅ Transcoded to: $path');
    }

    // If it's a network URL, download to a local cache file first
    String playPath = path;
    if (playPath.startsWith('http') || playPath.startsWith('HTTP')) {
      Logger.ui(
        'VoiceMessageView',
        '⬇️ network audio detected, downloading...',
      );
      final local = await _downloadVoiceToCache(playPath);
      if (local != null) {
        Logger.ui('VoiceMessageView', '💾 using cached file: $local');
        playPath = local;
      } else {
        Logger.error('VoiceMessageView: ❌ download failed for "$playPath"');
        // Avoid crashing the app; skip playback gracefully
        _isPrepared = false;
        return;
      }
    }

    try {
      await controller.preparePlayer(
        path: playPath,
        noOfSamples:
            widget.config?.playerWaveStyle?.getSamplesForWidth(
              widget.screenWidth * 0.5,
            ) ??
            playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
      );
      _isPrepared = true;
      Logger.ui(
        'VoiceMessageView',
        '🎧 prepared. maxDuration=${controller.maxDuration}ms',
      );
      widget.onMaxDuration?.call(controller.maxDuration);
    } catch (e, st) {
      _isPrepared = false;
      Logger.error(
        'VoiceMessageView: ❌ preparePlayer failed for "$playPath"',
        error: e,
        stackTrace: st,
      );
      // Avoid crashing the app on iOS/Android; just return
      return;
    }
  }

  Future<String?> _downloadVoiceToCache(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString(WKConstants.imTokenKey) ??
          prefs.getString(WKConstants.tokenKey) ??
          '';

      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/voice_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Derive filename from URL or message id
      final uri = Uri.parse(url);
      String name = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '${widget.message.id}.m4a';
      // Ensure name is safe
      name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

      final file = File('${cacheDir.path}/$name');
      if (await file.exists() && (await file.length()) > 0) {
        Logger.ui('VoiceMessageView', '⚠️ cache hit: ${file.path}');
        return file.path;
      }

      final dio = Dio();
      final headers = <String, String>{};
      if (token.isNotEmpty) headers['token'] = token;

      Logger.ui('VoiceMessageView', '⬇️ GET $url');
      final resp = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );

      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        Logger.error('VoiceMessageView: ❌ empty response for $url');
        return null;
      }

      await file.writeAsBytes(bytes, flush: true);
      Logger.ui(
        'VoiceMessageView',
        '✅ saved ${file.lengthSync()} bytes to ${file.path}',
      );
      return file.path;
    } catch (e, st) {
      Logger.error(
        'VoiceMessageView: ❌ download error for $url',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<String?> _transcodeAmrToM4a(String amrPath) async {
    try {
      final input = amrPath;
      String outPath;
      if (amrPath.toLowerCase().endsWith('.amr')) {
        outPath = '${amrPath.substring(0, amrPath.length - 4)}.m4a';
      } else {
        outPath = '$amrPath.m4a';
      }

      final outFile = File(outPath);
      if (await outFile.exists() && (await outFile.length()) > 0) {
        Logger.ui(
          'VoiceMessageView',
          '⚠️ transcode cache hit: ${outFile.path}',
        );
        return outFile.path;
      }

      Logger.ui('VoiceMessageView', '🔁 FFmpeg transcoding $input -> $outPath');
      final session = await FFmpegKit.execute(
        '-y -i "$input" -ac 1 -ar 16000 -c:a aac -b:a 48k "$outPath"',
      );
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        Logger.ui('VoiceMessageView', '✅ FFmpeg success: $outPath');
        return outPath;
      } else {
        final logs = await session.getOutput();
        Logger.error('FFmpeg failed (code=${rc?.getValue()}): $logs');
        return null;
      }
    } catch (e, st) {
      Logger.error(
        'VoiceMessageView: ❌ transcode error',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration:
              widget.config?.decoration ??
              BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isMessageBySender
                    ? widget.outgoingChatBubbleConfig?.color
                    : widget.inComingChatBubbleConfig?.color,
              ),
          padding:
              widget.config?.padding ??
              const EdgeInsets.symmetric(horizontal: 8),
          margin:
              widget.config?.margin ??
              EdgeInsets.symmetric(
                horizontal: 8,
                vertical: widget.message.reaction.reactions.isNotEmpty ? 15 : 0,
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<PlayerState>(
                builder: (context, state, child) {
                  return IconButton(
                    onPressed: _playOrPause,
                    icon:
                        state.isStopped || state.isPaused || state.isInitialised
                        ? widget.config?.playIcon ??
                              const Icon(Icons.play_arrow, color: Colors.white)
                        : widget.config?.pauseIcon ??
                              const Icon(Icons.stop, color: Colors.white),
                  );
                },
                valueListenable: _playerState,
              ),
              AudioFileWaveforms(
                size: Size(widget.screenWidth * 0.50, 60),
                playerController: controller,
                waveformType: WaveformType.fitWidth,
                playerWaveStyle:
                    widget.config?.playerWaveStyle ?? playerWaveStyle,
                padding:
                    widget.config?.waveformPadding ??
                    const EdgeInsets.only(right: 10),
                margin: widget.config?.waveformMargin,
                animationCurve: widget.config?.animationCurve ?? Curves.easeIn,
                animationDuration:
                    widget.config?.animationDuration ??
                    const Duration(milliseconds: 500),
                enableSeekGesture: widget.config?.enableSeekGesture ?? true,
              ),
            ],
          ),
        ),
        if (widget.message.reaction.reactions.isNotEmpty)
          ReactionWidget(
            isMessageBySender: widget.isMessageBySender,
            reaction: widget.message.reaction,
            messageReactionConfig: widget.messageReactionConfig,
          ),
      ],
    );
  }

  void _playOrPause() {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!_isPrepared) {
      Logger.ui(
        'VoiceMessageView',
        '🚫 Not prepared; ignoring play tap (msgId=${widget.message.id}) state=$playerState',
      );
      return;
    }

    if (playerState.isInitialised || playerState.isPaused) {
      Logger.ui(
        'VoiceMessageView',
        '▶️ start play (msgId=${widget.message.id}) state=$playerState',
      );
      controller.startPlayer();
      controller.setFinishMode(finishMode: FinishMode.pause);
    } else {
      Logger.ui(
        'VoiceMessageView',
        '⏸️ pause (msgId=${widget.message.id}) state=$playerState',
      );
      controller.pausePlayer();
    }
  }
}
