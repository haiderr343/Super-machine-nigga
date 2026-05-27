import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:provider/provider.dart';
import '../models/call_state.dart';
import '../providers/call_provider.dart';
import '../widgets/control_overlay.dart';
import '../widgets/floating_local_video.dart';

/// Active call screen.
///
/// Layout:
///   - Full-screen remote video (or placeholder when no remote user yet)
///   - Floating draggable local camera PiP (top layer)
///   - Auto-hiding bottom control overlay (top-most layer)
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final GlobalKey<_ControlOverlayWrapperState> _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Lock to portrait for the duration of the call.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // Full-screen immersive mode during call.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI and orientation after leaving the call.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _endCall(BuildContext context) async {
    await context.read<CallProvider>().leaveCall();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final callState = context.watch<CallProvider>().state;

    return PopScope(
      // Intercept back button — end call properly instead of just popping.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _endCall(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _overlayKey.currentState?.showOverlay(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Full-screen remote video / placeholder ────────────
              _RemoteVideoView(callState: callState),

              // ── Layer 2: Status indicator (top centre) ────────────────────
              _CallStatusBadge(callState: callState),

              // ── Layer 3: Draggable local PiP ──────────────────────────────
              const FloatingLocalVideo(),

              // ── Layer 4: Auto-hiding control overlay ──────────────────────
              _ControlOverlayWrapper(
                key: _overlayKey,
                onEndCall: () => _endCall(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Remote video view
// =============================================================================

class _RemoteVideoView extends StatelessWidget {
  final CallState callState;
  const _RemoteVideoView({required this.callState});

  @override
  Widget build(BuildContext context) {
    final engine = context.select<CallProvider, RtcEngine?>((p) => p.engine);

    // Audio-only call — never render a video surface.
    if (callState.callType == CallType.audioOnly) {
      return _AudioOnlyBackground(channelName: callState.channelName);
    }

    // Remote user connected with video.
    if (callState.remoteUid != null && engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: callState.remoteUid!),
          connection: RtcConnection(channelId: callState.channelName),
        ),
      );
    }

    // Joined but no remote participant yet.
    return _WaitingBackground(callState: callState);
  }
}

// =============================================================================
// Waiting / placeholder backgrounds
// =============================================================================

class _WaitingBackground extends StatelessWidget {
  final CallState callState;
  const _WaitingBackground({required this.callState});

  @override
  Widget build(BuildContext context) {
    final isConnecting = callState.status == CallStatus.connecting;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1117), Color(0xFF1A1F2E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 52,
                color: Colors.white30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isConnecting ? 'Connecting...' : 'Waiting for others to join',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            if (!isConnecting) ...[
              const SizedBox(height: 10),
              Text(
                callState.channelName,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
            if (isConnecting) ...[
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioOnlyBackground extends StatelessWidget {
  final String channelName;
  const _AudioOnlyBackground({required this.channelName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D1117), Color(0xFF162032)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 52,
                color: Color(0xFF64B5F6),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Audio Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              channelName,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Status badge
// =============================================================================

class _CallStatusBadge extends StatelessWidget {
  final CallState callState;
  const _CallStatusBadge({required this.callState});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;

    switch (callState.status) {
      case CallStatus.connecting:
        label = 'Connecting';
        color = Colors.orange;
      case CallStatus.connected:
        label = 'Waiting for participant';
        color = Colors.white54;
      case CallStatus.inCall:
        label = 'Connected';
        color = const Color(0xFF4CAF50);
      case CallStatus.error:
        label = callState.errorMessage ?? 'Error';
        color = Colors.red;
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Control overlay wrapper (exposes show() for tap-to-reveal)
// =============================================================================

class _ControlOverlayWrapper extends StatefulWidget {
  final VoidCallback onEndCall;
  const _ControlOverlayWrapper({super.key, required this.onEndCall});

  @override
  State<_ControlOverlayWrapper> createState() =>
      _ControlOverlayWrapperState();
}

class _ControlOverlayWrapperState extends State<_ControlOverlayWrapper> {
  final GlobalKey<ControlOverlayState> _controlKey = GlobalKey();

  void showOverlay() => _controlKey.currentState?.show();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ControlOverlay(
        key: _controlKey,
        onEndCall: widget.onEndCall,
      ),
    );
  }
}
