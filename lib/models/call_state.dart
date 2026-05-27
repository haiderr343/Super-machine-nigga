// Represents the current lifecycle state of a call session.
enum CallStatus {
  idle,         // No active call; showing Join screen
  connecting,   // Joining channel, waiting for Agora confirmation
  connected,    // Successfully joined; waiting for remote user
  inCall,       // Remote user has joined; active call in progress
  disconnected, // Call ended; transitioning back to Join screen
  error,        // Unrecoverable error occurred
}

// Tracks the type of call being initiated.
enum CallType {
  video,
  audioOnly,
}

/// Holds all mutable state for an active or pending call.
class CallState {
  final CallStatus status;
  final CallType callType;
  final String channelName;
  final int? remoteUid;         // UID of the joined remote user (null if none)
  final bool isMuted;           // Local microphone muted
  final bool isCameraOff;       // Local camera disabled
  final bool isFrontCamera;     // Using front-facing camera
  final String? errorMessage;   // Set when status == CallStatus.error

  const CallState({
    this.status = CallStatus.idle,
    this.callType = CallType.video,
    this.channelName = '',
    this.remoteUid,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.errorMessage,
  });

  bool get isActive =>
      status == CallStatus.connected || status == CallStatus.inCall;

  CallState copyWith({
    CallStatus? status,
    CallType? callType,
    String? channelName,
    int? remoteUid,
    bool clearRemoteUid = false,
    bool? isMuted,
    bool? isCameraOff,
    bool? isFrontCamera,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CallState(
      status: status ?? this.status,
      callType: callType ?? this.callType,
      channelName: channelName ?? this.channelName,
      remoteUid: clearRemoteUid ? null : (remoteUid ?? this.remoteUid),
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
