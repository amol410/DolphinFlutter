import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';

/// DolphinCoder 2.0 Splash Screen
/// Features glowing oceanic depth gradient, rising bubble physics,
/// 3D Pixar Leaping Dolphin Mascot, and seamless authentication check.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _bubbleController;
  late final AnimationController _mascotController;
  late final Animation<double> _mascotScale;
  late final Animation<double> _mascotFade;

  late final AnimationController _textController;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;

  late final AnimationController _pulseController;
  late final AnimationController _exitController;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Marine bubble flow
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Mascot entrance with elastic bounce
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mascotScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _mascotController, curve: Curves.elasticOut),
    );
    _mascotFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mascotController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    // Typography slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textSlide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Pulse dots for loading
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Exit transition
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _bootSequence();
  }

  Future<void> _bootSequence() async {
    // 1. Kickoff mascot reveal
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _mascotController.forward();

    // 2. Reveal brand text
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _textController.forward();

    // 3. Auth verification check (generous 3s for pleasant brand mascot feel)
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    if (!mounted) return;

    await _exitController.forward();
    if (!mounted) return;

    if (token != null) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _mascotController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // Layer 1: Radiant Oceanic Deep Gradient
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0284C7),
                    Color(0xFF0369A1),
                    Color(0xFF0F172A),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Layer 2: Floating rising water bubbles
            AnimatedBuilder(
              animation: _bubbleController,
              builder: (context, _) => CustomPaint(
                size: Size(size.width, size.height),
                painter: _MarineBubblesPainter(_bubbleController.value),
              ),
            ),

            // Layer 3: Central Content
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Leaping 3D Pixar Dolphin Mascot
                    AnimatedBuilder(
                      animation: _mascotController,
                      builder: (_, __) => FadeTransition(
                        opacity: _mascotFade,
                        child: Transform.scale(
                          scale: _mascotScale.value,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF06B6D4).withOpacity(0.35),
                                  blurRadius: 50,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const AnimatedDolphinMascot(
                              size: 195,
                              pose: MascotPose.jump,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Typography
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (_, __) => FadeTransition(
                        opacity: _textFade,
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Column(
                            children: [
                              Text(
                                'DolphinCoder',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Learn German naturally, one splash at a time.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFBAE6FD),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Subtle pulsating marine loading dots
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final delay = i * 0.25;
                            final curvedVal = math.sin((_pulseController.value * math.pi) + (delay * math.pi)).abs();
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 8 + (curvedVal * 4),
                              height: 8 + (curvedVal * 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.lerp(
                                  const Color(0xFF38BDF8),
                                  Colors.white,
                                  curvedVal,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for floating underwater bubbles
class _MarineBubblesPainter extends CustomPainter {
  final double progress;
  static final math.Random _rng = math.Random(42);

  // Pre-generate stable bubble seeds
  static final List<_BubbleSpec> _bubbles = List.generate(24, (i) {
    return _BubbleSpec(
      relX: _rng.nextDouble(),
      speed: 0.6 + (_rng.nextDouble() * 0.8),
      radius: 4.0 + (_rng.nextDouble() * 10.0),
      alpha: 0.12 + (_rng.nextDouble() * 0.25),
      wobbleFreq: 2.0 + (_rng.nextDouble() * 3.0),
    );
  });

  _MarineBubblesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bubbles) {
      final y = ((1.0 - ((progress * b.speed) % 1.0)) * (size.height + 40)) - 20;
      final wobble = math.sin((progress * 2 * math.pi * b.wobbleFreq) + (b.relX * 10)) * 14;
      final x = (b.relX * size.width) + wobble;

      final paint = Paint()
        ..color = const Color(0xFFBAE6FD).withOpacity(b.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      final fillPaint = Paint()
        ..color = const Color(0xFFBAE6FD).withOpacity(b.alpha * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), b.radius, fillPaint);
      canvas.drawCircle(Offset(x, y), b.radius, paint);

      // Bubble specular highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(b.alpha * 1.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(x - (b.radius * 0.35), y - (b.radius * 0.35)),
        b.radius * 0.22,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarineBubblesPainter oldDelegate) => true;
}

class _BubbleSpec {
  final double relX;
  final double speed;
  final double radius;
  final double alpha;
  final double wobbleFreq;

  const _BubbleSpec({
    required this.relX,
    required this.speed,
    required this.radius,
    required this.alpha,
    required this.wobbleFreq,
  });
}
