import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated vector cartoon character matching the Duolingo aesthetic in the screenshot.
/// Reacts dynamically to:
/// - [isTalking]: moves mouth in sync with audio playback.
/// - [isListening]: tilts head and perks up when microphone is recording.
/// - [isCelebrating]: celebratory expression, smiling eyes, and victory confetti.
class AnimatedKaraokeCharacter extends StatefulWidget {
  final bool isTalking;
  final bool isListening;
  final bool isCelebrating;
  final double size;
  final VoidCallback? onTap;

  const AnimatedKaraokeCharacter({
    super.key,
    required this.isTalking,
    this.isListening = false,
    this.isCelebrating = false,
    this.size = 140,
    this.onTap,
  });

  @override
  State<AnimatedKaraokeCharacter> createState() => _AnimatedKaraokeCharacterState();
}

class _AnimatedKaraokeCharacterState extends State<AnimatedKaraokeCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _blinkController;
  late final AnimationController _mouthController;
  late final AnimationController _celebrateController;

  @override
  void initState() {
    super.initState();

    // Gentle breathing/swaying loop
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Eye blinking loop (blinks once every ~3.5 seconds)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Lip-sync mouth oscillation
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    // Celebration sparkle oscillation
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    if (widget.isTalking) {
      _mouthController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedKaraokeCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking != oldWidget.isTalking) {
      if (widget.isTalking) {
        _mouthController.repeat(reverse: true);
      } else {
        _mouthController.animateTo(0, duration: const Duration(milliseconds: 80));
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _blinkController.dispose();
    _mouthController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathController,
          _blinkController,
          _mouthController,
          _celebrateController,
        ]),
        builder: (context, child) {
          // Blink value: only close eyes during the last 150ms of the 3200ms cycle
          final blinkProgress = _blinkController.value;
          final isBlinking = blinkProgress > 0.94;

          final breathOffset = math.sin(_breathController.value * math.pi) * 3.0;
          final headTilt = widget.isListening ? 0.08 : (math.sin(_breathController.value * math.pi) * 0.02);
          final mouthOpen = widget.isTalking ? _mouthController.value : 0.0;
          final celebrateSparkle = _celebrateController.value;

          return SizedBox(
            width: widget.size,
            height: widget.size * 1.35,
            child: CustomPaint(
              painter: _CharacterPainter(
                breathOffset: breathOffset,
                headTilt: headTilt,
                mouthOpen: mouthOpen,
                isBlinking: isBlinking,
                isListening: widget.isListening,
                isCelebrating: widget.isCelebrating,
                sparkleProgress: celebrateSparkle,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final double breathOffset;
  final double headTilt;
  final double mouthOpen;
  final bool isBlinking;
  final bool isListening;
  final bool isCelebrating;
  final double sparkleProgress;

  _CharacterPainter({
    required this.breathOffset,
    required this.headTilt,
    required this.mouthOpen,
    required this.isBlinking,
    required this.isListening,
    required this.isCelebrating,
    required this.sparkleProgress,
  });

  // Palette based on the screenshot character
  static const Color hairColor = Color(0xFF2C2420);
  static const Color skinColor = Color(0xFFB06F44);
  static const Color skinShadow = Color(0xFF96562D);
  static const Color headbandColor = Color(0xFFFFAE19);
  static const Color headbandShadow = Color(0xFFE59400);
  static const Color shirtColor = Color(0xFFFFAE19);
  static const Color pantsColor = Color(0xFF1CB0F6);
  static const Color suspenderColor = Color(0xFFE53935);
  static const Color eyeWhite = Colors.white;
  static const Color pupilColor = Color(0xFF201610);
  static const Color mouthInner = Color(0xFF6A1A24);
  static const Color tongueColor = Color(0xFFFF6F7D);
  static const Color teethColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140.0;
    canvas.save();
    canvas.scale(scale);

    // Apply breathing translation
    canvas.translate(0, breathOffset);

    // 1. Draw celebratory sparkles / stars if celebrating
    if (isCelebrating) {
      _drawSparkles(canvas, sparkleProgress);
    }

    // 2. Draw Torso / Clothes (Behind Head)
    _drawTorso(canvas);

    // 3. Draw Head, Hair Bun, and Face with tilt
    canvas.save();
    // Pivot around neck / chin (x: 70, y: 85)
    canvas.translate(70, 85);
    canvas.rotate(headTilt);
    canvas.translate(-70, -85);

    _drawHairBun(canvas);
    _drawHeadAndEars(canvas);
    _drawHeadband(canvas);
    _drawFaceFeatures(canvas);

    canvas.restore();

    // 4. Draw Arms & Hands (In front of torso)
    _drawArms(canvas);

    canvas.restore();
  }

  void _drawTorso(Canvas canvas) {
    final shirtPaint = Paint()..color = shirtColor;
    final pantsPaint = Paint()..color = pantsColor;

    // Yellow shirt body
    final shirtPath = Path()
      ..moveTo(48, 86)
      ..lineTo(92, 86)
      ..lineTo(98, 128)
      ..lineTo(42, 128)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);

    // Blue pants / skirt below waist
    final pantsPath = Path()
      ..moveTo(40, 126)
      ..lineTo(100, 126)
      ..lineTo(104, 155)
      ..lineTo(36, 155)
      ..close();
    canvas.drawPath(pantsPath, pantsPaint);

    // Red suspenders / straps
    final suspenderPaint = Paint()
      ..color = suspenderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(54, 88), const Offset(52, 126), suspenderPaint);
    canvas.drawLine(const Offset(86, 88), const Offset(88, 126), suspenderPaint);

    // Neck
    final neckPaint = Paint()..color = skinShadow;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 76, 16, 16),
        const Radius.circular(6),
      ),
      neckPaint,
    );
  }

  void _drawArms(Canvas canvas) {
    final armPaint = Paint()
      ..color = skinColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    if (isCelebrating) {
      // Arms raised in joyful celebration!
      final leftArm = Path()
        ..moveTo(46, 94)
        ..quadraticBezierTo(25, 75, 20, 50);
      final rightArm = Path()
        ..moveTo(94, 94)
        ..quadraticBezierTo(115, 75, 120, 50);
      canvas.drawPath(leftArm, armPaint);
      canvas.drawPath(rightArm, armPaint);

      // Hands
      final handPaint = Paint()..color = skinColor;
      canvas.drawCircle(const Offset(20, 48), 7, handPaint);
      canvas.drawCircle(const Offset(120, 48), 7, handPaint);
    } else if (isListening) {
      // Left arm resting, Right hand cupping ear to listen!
      final leftArm = Path()
        ..moveTo(46, 94)
        ..quadraticBezierTo(38, 112, 48, 122);
      final rightArm = Path()
        ..moveTo(94, 94)
        ..quadraticBezierTo(112, 90, 108, 62);
      canvas.drawPath(leftArm, armPaint);
      canvas.drawPath(rightArm, armPaint);

      final handPaint = Paint()..color = skinColor;
      canvas.drawCircle(const Offset(108, 60), 7, handPaint);
    } else {
      // Normal pose matching screenshot: left arm slightly bent, right hand resting forward
      final leftArm = Path()
        ..moveTo(46, 94)
        ..quadraticBezierTo(35, 110, 42, 126);
      final rightArm = Path()
        ..moveTo(94, 94)
        ..quadraticBezierTo(92, 112, 80, 118);
      canvas.drawPath(leftArm, armPaint);
      canvas.drawPath(rightArm, armPaint);

      // Hand resting at chest
      final handPaint = Paint()..color = skinColor;
      canvas.drawCircle(const Offset(78, 118), 7, handPaint);
    }
  }

  void _drawHairBun(Canvas canvas) {
    final hairPaint = Paint()..color = hairColor;

    // Big curly high puff / bun on top
    canvas.drawCircle(const Offset(70, 24), 26, hairPaint);
    canvas.drawCircle(const Offset(52, 28), 18, hairPaint);
    canvas.drawCircle(const Offset(88, 28), 18, hairPaint);
    canvas.drawCircle(const Offset(70, 12), 16, hairPaint);

    // Hair base behind head
    canvas.drawCircle(const Offset(44, 46), 18, hairPaint);
    canvas.drawCircle(const Offset(96, 46), 18, hairPaint);
  }

  void _drawHeadAndEars(Canvas canvas) {
    final skinPaint = Paint()..color = skinColor;
    final earPaint = Paint()..color = skinColor;
    final earInner = Paint()..color = skinShadow;

    // Ears
    canvas.drawCircle(const Offset(38, 60), 8, earPaint);
    canvas.drawCircle(const Offset(38, 60), 4, earInner);
    canvas.drawCircle(const Offset(102, 60), 8, earPaint);
    canvas.drawCircle(const Offset(102, 60), 4, earInner);

    // Main Face / Head shape
    final faceRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 34, 56, 52),
      const Radius.circular(26),
    );
    canvas.drawRRect(faceRect, skinPaint);
  }

  void _drawHeadband(Canvas canvas) {
    final bandPaint = Paint()..color = headbandColor;
    final knotPaint = Paint()..color = headbandShadow;

    // Headband wrapping across upper forehead
    final bandPath = Path()
      ..moveTo(40, 42)
      ..quadraticBezierTo(70, 46, 100, 42)
      ..lineTo(100, 50)
      ..quadraticBezierTo(70, 54, 40, 50)
      ..close();
    canvas.drawPath(bandPath, bandPaint);

    // Cute headband knot / ribbon on top center
    final knotPath = Path()
      ..moveTo(70, 38)
      ..lineTo(64, 30)
      ..lineTo(70, 34)
      ..lineTo(76, 30)
      ..close();
    canvas.drawPath(knotPath, knotPaint);
    canvas.drawCircle(const Offset(70, 36), 4, knotPaint);
  }

  void _drawFaceFeatures(Canvas canvas) {
    // 1. Eyebrows
    final browPaint = Paint()
      ..color = hairColor
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isCelebrating) {
      // Happy arched high eyebrows
      canvas.drawArc(const Rect.fromLTWH(50, 47, 14, 8), math.pi, math.pi, false, browPaint);
      canvas.drawArc(const Rect.fromLTWH(76, 47, 14, 8), math.pi, math.pi, false, browPaint);
    } else if (isListening) {
      // Inquisitive / tilted eyebrows
      canvas.drawLine(const Offset(51, 55), const Offset(63, 51), browPaint);
      canvas.drawLine(const Offset(77, 51), const Offset(89, 53), browPaint);
    } else {
      // Confident, slightly raised eyebrows matching screenshot
      canvas.drawLine(const Offset(50, 54), const Offset(64, 52), browPaint);
      canvas.drawLine(const Offset(76, 52), const Offset(90, 54), browPaint);
    }

    // 2. Eyes
    if (isBlinking) {
      // Closed line eyes during blink
      final blinkPaint = Paint()
        ..color = pupilColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(51, 62), const Offset(63, 62), blinkPaint);
      canvas.drawLine(const Offset(77, 62), const Offset(89, 62), blinkPaint);
    } else if (isCelebrating) {
      // Happy curved closed eyes (^ ^)
      final happyEyePaint = Paint()
        ..color = pupilColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(const Rect.fromLTWH(50, 56, 14, 10), math.pi * 1.1, math.pi * 0.8, false, happyEyePaint);
      canvas.drawArc(const Rect.fromLTWH(76, 56, 14, 10), math.pi * 1.1, math.pi * 0.8, false, happyEyePaint);
    } else {
      // Open cartoon eyes with pupils and white shine
      final eyeBgPaint = Paint()..color = eyeWhite;
      final pupilPaint = Paint()..color = pupilColor;
      final shinePaint = Paint()..color = Colors.white;

      // Left eye
      canvas.drawOval(const Rect.fromLTWH(51, 56, 13, 11), eyeBgPaint);
      // Right eye
      canvas.drawOval(const Rect.fromLTWH(76, 56, 13, 11), eyeBgPaint);

      // Pupils (glancing slightly to the right towards the speech bubble!)
      final pupilOffset = isListening ? 0.0 : 1.5;
      canvas.drawCircle(Offset(58 + pupilOffset, 61), 4.2, pupilPaint);
      canvas.drawCircle(Offset(83 + pupilOffset, 61), 4.2, pupilPaint);

      // White shine dots
      canvas.drawCircle(Offset(59 + pupilOffset, 59.5), 1.6, shinePaint);
      canvas.drawCircle(Offset(84 + pupilOffset, 59.5), 1.6, shinePaint);
    }

    // 3. Cute Button Nose
    final nosePaint = Paint()
      ..color = skinShadow
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(const Rect.fromLTWH(67, 65, 6, 5), 0, math.pi, false, nosePaint);

    // 4. Animated Mouth (Lip-Sync Engine)
    _drawMouth(canvas);
  }

  void _drawMouth(Canvas canvas) {
    if (isCelebrating) {
      // Wide open cheerful smile
      final mouthPath = Path()
        ..moveTo(56, 73)
        ..quadraticBezierTo(70, 87, 84, 73)
        ..close();
      canvas.drawPath(mouthPath, Paint()..color = mouthInner);

      // Teeth
      final teethPath = Path()
        ..moveTo(58, 73)
        ..lineTo(82, 73)
        ..quadraticBezierTo(70, 77, 58, 73)
        ..close();
      canvas.drawPath(teethPath, Paint()..color = teethColor);

      // Tongue
      final tonguePath = Path()
        ..moveTo(64, 82)
        ..quadraticBezierTo(70, 77, 76, 82)
        ..quadraticBezierTo(70, 86, 64, 82)
        ..close();
      canvas.drawPath(tonguePath, Paint()..color = tongueColor);
      return;
    }

    if (mouthOpen > 0.1) {
      // Talking animation: mouth opens and articulates dynamically with teeth and tongue
      final openH = 4.0 + (mouthOpen * 9.0);
      final mouthPath = Path()
        ..moveTo(58, 73)
        ..quadraticBezierTo(70, 73 + openH, 82, 73)
        ..quadraticBezierTo(70, 71, 58, 73)
        ..close();
      canvas.drawPath(mouthPath, Paint()..color = mouthInner);

      // Teeth strip
      final teethPath = Path()
        ..moveTo(61, 73)
        ..lineTo(79, 73)
        ..lineTo(77, 75.5)
        ..lineTo(63, 75.5)
        ..close();
      canvas.drawPath(teethPath, Paint()..color = teethColor);

      // Tongue bump
      if (openH > 7.0) {
        canvas.drawCircle(Offset(70, 72 + openH), 4.5, Paint()..color = tongueColor);
      }
    } else {
      // Closed mouth / confident smile matching the screenshot
      final lipPaint = Paint()
        ..color = pupilColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final smilePath = Path()
        ..moveTo(59, 73)
        ..quadraticBezierTo(68, 77, 81, 72);
      canvas.drawPath(smilePath, lipPaint);
    }
  }

  void _drawSparkles(Canvas canvas, double progress) {
    final starPaint = Paint()..color = const Color(0xFFFFD700);

    // Left star
    _drawStar(canvas, Offset(24, 30 + (progress * 4)), 7, starPaint);
    // Right star
    _drawStar(canvas, Offset(118, 22 - (progress * 4)), 9, starPaint);
    // Little dot
    canvas.drawCircle(Offset(18, 55 + (progress * 2)), 3, starPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final double x = center.dx + r * math.cos(i * 4 * math.pi / 5 - math.pi / 2);
      final double y = center.dy + r * math.sin(i * 4 * math.pi / 5 - math.pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) {
    return oldDelegate.breathOffset != breathOffset ||
        oldDelegate.headTilt != headTilt ||
        oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isCelebrating != isCelebrating ||
        oldDelegate.sparkleProgress != sparkleProgress;
  }
}
