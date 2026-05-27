import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora_config.dart';
import '../models/call_state.dart';

/// Manages the entire Agora RTC engine lifecycle and exposes call state
/// to the widget tree via ChangeNotifier / Provider.
class CallProvider extends ChangeNotifier {
  RtcEngine? _engine;
  CallState _state = const CallState();

  CallState get state => _state;
  RtcEngine? get engine => _engine;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Requests device permissions and joins the specified channel.
  Future<void> joinCall({
    required String channelName,
    required CallType callType,
  }) async {
    _updateState(_state.copyWith(
      status: CallStatus.connecting,
      channelName: channelName,
      callType: callType,
      clearError: true,
    ));

    // Request camera + microphone at runtime before doing anything else.
    final granted = await _requestPermissions(callType);
    if (!granted) {
      _updateState(_state.copyWith(
        status: CallStatus.error,
        errorMessage:
            'Camera and microphone permissions are required to join a call.',
      ));
      return;
    }

    try {
      await _initEngine();
      await _joinChannel(channelName: channelName, callType: callType);
    } catch (e) {
      _updateState(_state.copyWith(
        status: CallStatus.error,
        errorMessage: 'Failed to start call: ${e.toString()}',
      ));
    }
  }

  /// Ends the active call, leaves the channel, and resets state.
  Future<void> leaveCall() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _updateState(const CallState(status: CallStatus.idle));
  }

  /// Toggles the local microphone mute state.
  Future<void> toggleMute() async {
    final muted = !_state.isMuted;
    await _engine?.muteLocalAudioStream(muted);
    _updateState(_state.copyWith(isMuted: muted));
  }

  /// Toggles the local camera on/off.
  Future<void> toggleCamera() async {
    final off = !_state.isCameraOff;
    await _engine?.muteLocalVideoStream(off);
    _updateState(_state.copyWith(isCameraOff: off));
  }

  /// Switches between front and rear cameras.
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    _updateState(_state.copyWith(isFrontCamera: !_state.isFrontCamera));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _updateState(CallState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Initialises the RTC engine with event handlers.
  Future<void> _initEngine() async {
    _engine = createAgoraRtcEngine();

    await _engine!.initialize(RtcEngineContext(
      appId: AgoraConfig.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register all event handlers to handle the full call lifecycle.
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        // Successfully joined the channel.
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId}');
          _updateState(_state.copyWith(status: CallStatus.connected));
        },

        // A remote user joined the channel.
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[Agora] Remote user joined: $remoteUid');
          _updateState(_state.copyWith(
            status: CallStatus.inCall,
            remoteUid: remoteUid,
          ));
        },

        // A remote user left the channel (disconnected or dropped).
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('[Agora] Remote user offline: $remoteUid reason: $reason');
          _updateState(_state.copyWith(
            status: CallStatus.connected,
            clearRemoteUid: true,
          ));
        },

        // Remote user muted/unmuted their audio.
        onUserMuteAudio: (RtcConnection connection, int remoteUid,
            bool muted) {
          debugPrint('[Agora] Remote $remoteUid audio muted: $muted');
        },

        // Remote user enabled/disabled their video.
        onUserMuteVideo: (RtcConnection connection, int remoteUid,
            bool muted) {
          debugPrint('[Agora] Remote $remoteUid video muted: $muted');
        },

        // Local user left the channel.
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[Agora] Left channel');
          _updateState(_state.copyWith(status: CallStatus.disconnected));
        },

        // Network or token-related errors.
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora] Error $err: $msg');
          _updateState(_state.copyWith(
            status: CallStatus.error,
            errorMessage: 'Connection error: $msg',
          ));
        },

        // Token has expired — in production you'd refresh it here.
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('[Agora] Token will expire');
        },

        // Connection state changes (reconnecting, disconnected, etc.).
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[Agora] Connection state: $state reason: $reason');
        },
      ),
    );

    // Enable video subsystem regardless of call type (audio-only calls
    // simply leave video muted; the engine still needs to be initialized).
    await _engine!.enableVideo();
    await _engine!.startPreview();
  }

  /// Configures channel options and calls joinChannel.
  Future<void> _joinChannel({
    required String channelName,
    required CallType callType,
  }) async {
    final isAudioOnly = callType == CallType.audioOnly;

    await _engine!.joinChannel(
      token: AgoraConfig.token.isEmpty ? '' : AgoraConfig.token,
      channelId: channelName,
      uid: AgoraConfig.localUid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        // Publish local audio always
        publishMicrophoneTrack: true,
        // Publish local video only for video calls
        publishCameraTrack: !isAudioOnly,
        // Auto-subscribe to remote streams
        autoSubscribeAudio: true,
        autoSubscribeVideo: !isAudioOnly,
      ),
    );

    // For audio-only calls, mute the local camera immediately after joining.
    if (isAudioOnly) {
      await _engine!.muteLocalVideoStream(true);
      _updateState(_state.copyWith(isCameraOff: true));
    }
  }

  /// Requests required permissions. Returns true only if all were granted.
  Future<bool> _requestPermissions(CallType callType) async {
    final permissions = [Permission.microphone];
    if (callType == CallType.video) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();

    for (final entry in statuses.entries) {
      if (!entry.value.isGranted) {
        debugPrint('[Permissions] Denied: ${entry.key}');
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}
