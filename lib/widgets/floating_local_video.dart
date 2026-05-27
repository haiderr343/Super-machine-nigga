import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:provider/provider.dart';
import '../models/call_state.dart';
import '../providers/call_provider.dart';

/// A small draggable picture-in-picture window showing the local camera feed.
/// Renders an avatar placeholder when the camera is off or audio-only mode is on.
class FloatingLocalVideo extends StatefulWidget {
  const FloatingLocalVideo({super.key});

  @override
  State<FloatingLocalVideo> createState() => _FloatingLocalVideoState();
}

class _FloatingLocalVideoState extends State<FloatingLocalVideo> {
  // PiP dimensions
  static const double _pipWidth = 110;
  static const double _pipHeight = 155;
  static const double _margin = 16;

  // Track drag position
  late double _posX;
  late double _posY;
  bool _positioned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial position (top-right corner) once we know screen size.
    if (!_positioned) {
      final size = MediaQuery.of(context).size;
      _posX = size.width - _pipWidth - _margin;
      _posY = _margin + MediaQuery.of(context).padding.top + 16;
      _positioned = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = context.select<CallProvider, CallState>((p) => p.state);
    final engine = context.select<CallProvider, RtcEngine?>((p) => p.engine);
    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _posX,
      top: _posY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _posX = (_posX + details.delta.dx).clamp(
              0,
              size.width - _pipWidth,
            );
            _posY = (_posY + details.delta.dy).clamp(
              MediaQuery.of(context).padding.top,
              size.height - _pipHeight - MediaQuery.of(context).padding.bottom,
            );
          });
        },
        child: Container(
          width: _pipWidth,
          height: _pipHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.5),
            child: _buildVideoContent(callState, engine),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(CallState callState, RtcEngine? engine) {
    final showPlaceholder = callState.isCameraOff ||
        callState.callType == CallType.audioOnly ||
        engine == null;

    if (showPlaceholder) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.person_rounded,
            color: Colors.white38,
            size: 40,
          ),
        ),
      );
    }

    // Render the local camera preview via Agora's AgoraVideoView.
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }
}
