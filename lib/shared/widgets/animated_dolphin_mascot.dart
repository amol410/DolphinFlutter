import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MascotAccessory { none, snorkel, backpack, graduationCap, trophy, sunglasses }

enum MascotPose {
  jump,
  reading,
  waving,
  graduation,
  thinking,
  celebrate,
  letters,
  flag,
  headphones,
  backpack,
}

/// Echo the Polyglot Dolphin — 3D Rendered Pixar-Style Mascot
/// Features exact high-res 3D poses, smooth idle oceanic floating,
/// interactive tap bounce, and talk/listen/celebrate micro-reactions.
class AnimatedDolphinMascot extends StatefulWidget {
  final double size;
  final MascotPose? pose;
  final bool isTalking;
  final bool isListening;
  final bool isCelebrating;
  final MascotAccessory accessory;
  final VoidCallback? onTap;
  final bool animate;

  const AnimatedDolphinMascot({
    super.key,
    this.size = 110,
    this.pose,
    this.isTalking = false,
    this.isListening = false,
    this.isCelebrating = false,
    this.accessory = MascotAccessory.none,
    this.onTap,
    this.animate = true,
  });

  @override
  State<AnimatedDolphinMascot> createState() => _AnimatedDolphinMascotState();
}

class _AnimatedDolphinMascotState extends State<AnimatedDolphinMascot>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _tapBounceController;
  late final AnimationController _talkController;

  @override
  void initState() {
    super.initState();

    // 1. Gentle oceanic breathing & swimming float
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.animate) {
      _floatController.repeat(reverse: true);
    }

    // 2. Interactive squash & bounce on tap
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // 3. Talking pulse
    _talkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    if (widget.isTalking) {
      _talkController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedDolphinMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking != oldWidget.isTalking) {
      if (widget.isTalking) {
        _talkController.repeat(reverse: true);
      } else {
        _talkController.stop();
        _talkController.reset();
      }
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _tapBounceController.dispose();
    _talkController.dispose();
    super.dispose();
  }

  MascotPose get _effectivePose {
    if (widget.isCelebrating) return MascotPose.celebrate;
    if (widget.pose != null) return widget.pose!;
    if (widget.isListening) return MascotPose.headphones;
    if (widget.accessory == MascotAccessory.graduationCap) return MascotPose.graduation;
    if (widget.accessory == MascotAccessory.backpack) return MascotPose.backpack;
    if (widget.size >= 130) return MascotPose.jump;
    return MascotPose.waving;
  }

  String get _assetPath {
    switch (_effectivePose) {
      case MascotPose.jump:
        return 'assets/images/mascot/dolphin_jump.png';
      case MascotPose.reading:
        return 'assets/images/mascot/dolphin_reading.png';
      case MascotPose.waving:
        return 'assets/images/mascot/dolphin_waving.png';
      case MascotPose.graduation:
        return 'assets/images/mascot/dolphin_graduation.png';
      case MascotPose.thinking:
        return 'assets/images/mascot/dolphin_thinking.png';
      case MascotPose.celebrate:
        return 'assets/images/mascot/dolphin_celebrate.png';
      case MascotPose.letters:
        return 'assets/images/mascot/dolphin_letters.png';
      case MascotPose.flag:
        return 'assets/images/mascot/dolphin_flag.png';
      case MascotPose.headphones:
        return 'assets/images/mascot/dolphin_headphones.png';
      case MascotPose.backpack:
        return 'assets/images/mascot/dolphin_backpack.png';
    }
  }

  void _handleTap() {
    _tapBounceController.forward(from: 0.0).then((_) {
      if (mounted) _tapBounceController.reverse();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_floatController, _tapBounceController, _talkController]),
        builder: (context, child) {
          // Floating offset & tilt
          final floatVal = _floatController.value;
          final dy = widget.animate ? math.sin(floatVal * math.pi) * 5.0 : 0.0;
          final angle = widget.animate ? math.sin(floatVal * math.pi) * 0.03 : 0.0;

          // Tap bounce scale
          final bounceVal = _tapBounceController.value;
          final bounceScale = 1.0 + math.sin(bounceVal * math.pi) * 0.12;

          // Talking pulse
          final talkVal = widget.isTalking ? math.sin(_talkController.value * math.pi) * 0.06 : 0.0;

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scaleY: bounceScale + talkVal,
                scaleX: bounceScale - (talkVal * 0.5),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Image.asset(
                    _assetPath,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
