import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/speech_recognition_service.dart';

/// Interactive Duolingo-style Speaking Microphone Button
/// Features:
/// - Concentric animated ripples driven by real-time RMS sound levels
/// - Tactile haptic feedback on interaction and state change
/// - Clear visual status: idle, listening, processing, success, error
class SpeakingMicButton extends StatefulWidget {
  final SpeechServiceState state;
  final Stream<double> soundLevelStream;
  final VoidCallback onTap;
  final double size;

  const SpeakingMicButton({
    super.key,
    required this.state,
    required this.soundLevelStream,
    required this.onTap,
    this.size = 80.0,
  });

  @override
  State<SpeakingMicButton> createState() => _SpeakingMicButtonState();
}

class _SpeakingMicButtonState extends State<SpeakingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rippleController;
  StreamSubscription<double>? _soundSub;
  double _currentLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _soundSub = widget.soundLevelStream.listen((level) {
      if (mounted) {
        setState(() {
          _currentLevel = level;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant SpeakingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      if (widget.state == SpeechServiceState.listening) {
        HapticFeedback.mediumImpact();
        if (!_rippleController.isAnimating) _rippleController.repeat();
      } else {
        _currentLevel = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _soundSub?.cancel();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.state == SpeechServiceState.listening;
    final isProcessing = widget.state == SpeechServiceState.processing;
    final isError = widget.state == SpeechServiceState.error;

    // Amplitude scaling for ripple effect
    final levelScale = 1.0 + (_currentLevel * 0.45);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: SizedBox(
        width: widget.size * 1.8,
        height: widget.size * 1.8,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer dynamic sound ripple 1
            if (isListening)
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final progress = _rippleController.value;
                  final scale = 1.0 + (progress * 0.55 * levelScale);
                  final opacity = (1.0 - progress).clamp(0.0, 0.4);

                  return Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(alpha: opacity),
                    ),
                  );
                },
              ),

            // Outer dynamic sound ripple 2
            if (isListening)
              AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final progress = (_rippleController.value + 0.5) % 1.0;
                  final scale = 1.0 + (progress * 0.45 * levelScale);
                  final opacity = (1.0 - progress).clamp(0.0, 0.3);

                  return Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF60A5FA).withValues(alpha: opacity),
                    ),
                  );
                },
              ),

            // Inner core button container
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: widget.size * (isListening ? (1.0 + _currentLevel * 0.12) : 1.0),
              height: widget.size * (isListening ? (1.0 + _currentLevel * 0.12) : 1.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isListening
                      ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                      : isProcessing
                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                          : isError
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isListening
                            ? const Color(0xFF2563EB)
                            : isError
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6))
                        .withValues(alpha: isListening ? 0.45 : 0.25),
                    blurRadius: isListening ? 20.0 : 12.0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isProcessing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isListening
                            ? Icons.mic_rounded
                            : isError
                                ? Icons.mic_off_rounded
                                : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: widget.size * 0.45,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
