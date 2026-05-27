import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_state.dart';
import '../providers/call_provider.dart';

/// Bottom control bar overlay that auto-hides after [_hideDelay] of inactivity.
/// Tapping anywhere on the call screen re-shows it.
class ControlOverlay extends StatefulWidget {
  /// Called when the user taps "End Call".
  final VoidCallback onEndCall;

  const ControlOverlay({super.key, required this.onEndCall});

  @override
  State<ControlOverlay> createState() => ControlOverlayState();
}

// Expose state publicly so CallScreen can call show() via GlobalKey.
// ignore: library_private_types_in_public_api
class ControlOverlayState extends State<ControlOverlay>
    with SingleTickerProviderStateMixin {
  static const _hideDelay = Duration(seconds: 4);

  bool _visible = true;
  Timer? _hideTimer;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // start visible
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Visibility management
  // ---------------------------------------------------------------------------

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _visible = false);
    _controller.reverse();
  }

  /// Called when the user taps the screen — re-shows the overlay.
  void show() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _visible = true);
    _controller.forward();
    _startHideTimer();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.select<CallProvider, CallState>((p) => p.state);
    final isAudioOnly = state.callType == CallType.audioOnly;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: show,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 36,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  // Frosted-glass dark panel
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ── Toggle Camera ─────────────────────────────────────────
                    _ControlButton(
                      icon: state.isCameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: state.isCameraOff ? 'Camera Off' : 'Camera',
                      active: !state.isCameraOff,
                      enabled: !isAudioOnly,
                      onTap: () {
                        show();
                        context.read<CallProvider>().toggleCamera();
                      },
                    ),

                    // ── Mute Microphone ───────────────────────────────────────
                    _ControlButton(
                      icon: state.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: state.isMuted ? 'Unmute' : 'Mute',
                      active: !state.isMuted,
                      onTap: () {
                        show();
                        context.read<CallProvider>().toggleMute();
                      },
                    ),

                    // ── Switch Camera ─────────────────────────────────────────
                    _ControlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      enabled: !isAudioOnly && !state.isCameraOff,
                      onTap: () {
                        show();
                        context.read<CallProvider>().switchCamera();
                      },
                    ),

                    // ── End Call ──────────────────────────────────────────────
                    _ControlButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      isEndCall: true,
                      onTap: widget.onEndCall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Individual control button widget
// -----------------------------------------------------------------------------

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;
  final bool isEndCall;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = true,
    this.enabled = true,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine background and icon color based on state.
    final Color bgColor;
    final Color iconColor;

    if (isEndCall) {
      bgColor = const Color(0xFFD32F2F); // Material error red
      iconColor = Colors.white;
    } else if (!enabled) {
      bgColor = Colors.white.withOpacity(0.06);
      iconColor = Colors.white24;
    } else if (!active) {
      bgColor = Colors.white.withOpacity(0.15);
      iconColor = Colors.white54;
    } else {
      bgColor = Colors.white.withOpacity(0.18);
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white70 : Colors.white24,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
