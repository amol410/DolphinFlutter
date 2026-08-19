import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1 — background glow pulse
  late AnimationController _bgController;

  // Phase 2 — logo entrance (scale + fade)
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  // Phase 3 — text slide up + fade in
  late AnimationController _textController;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;

  // Phase 4 — dots pulse (loading indicator)
  late AnimationController _dotsController;

  // Phase 5 — exit fade
  late AnimationController _exitController;
  late Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Background glow — slow infinite pulse
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Logo entrance — 700ms, delayed 200ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Text slide — 500ms, delayed after logo
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Dots pulse — infinite
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Exit fade out
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Small pause before logo appears
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();

    // Text appears after logo settles
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textController.forward();

    // Check auth after 2.2s total
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;

    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    if (!mounted) return;

    // Fade out before navigating
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
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Layer 1: Animated background orbs ──────────────────────
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) {
                final t = _bgController.value;
                return CustomPaint(
                  size: Size(size.width, size.height),
                  painter: _BackgroundPainter(t),
                );
              },
            ),

            // ── Layer 2: Content ────────────────────────────────────────
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                  const Spacer(flex: 3),

                  // Logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (_, __) => FadeTransition(
                      opacity: _logoFade,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: const _DolphinLogo(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (_, __) => FadeTransition(
                      opacity: _textFade,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            // App name with gradient
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppColors.primaryGradient.createShader(bounds),
                              child: Text(
                                'DolphinCoder',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Learn · Practice · Master',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Animated dots loading indicator
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (_, child) => FadeTransition(
                      opacity: _textFade,
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 56),
                      child: _PulsingDots(controller: _dotsController),
                    ),
                  ),
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

// ─────────────────────────────────────────────────────────────────
// Dolphin Logo Widget
// ─────────────────────────────────────────────────────────────────
class _DolphinLogo extends StatelessWidget {
  const _DolphinLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F3A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 60,
            spreadRadius: -4,
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner glow ring
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.06),
              ),
            ),
            // Logo image (or fallback painter)
            const _LogoImage(),
          ],
        ),
      ),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: 90,
      height: 90,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => CustomPaint(
        size: const Size(80, 80),
        painter: _DolphinPainter(),
      ),
    );
  }
}

// Fallback: hand-drawn dolphin if image asset fails to load
class _DolphinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Dolphin body arc
    final path = Path();
    path.moveTo(cx - 30, cy + 10);
    path.cubicTo(cx - 20, cy - 25, cx + 20, cy - 25, cx + 35, cy);
    path.cubicTo(cx + 20, cy + 15, cx - 10, cy + 20, cx - 30, cy + 10);
    // Dorsal fin
    path.moveTo(cx, cy - 15);
    path.cubicTo(cx + 5, cy - 30, cx + 15, cy - 25, cx + 10, cy - 10);
    // Tail
    path.moveTo(cx - 28, cy + 10);
    path.cubicTo(cx - 38, cy + 5, cx - 40, cy - 5, cx - 35, cy - 8);
    path.cubicTo(cx - 38, cy - 2, cx - 40, cy + 10, cx - 32, cy + 18);

    canvas.drawPath(path, paint);

    // Eye
    canvas.drawCircle(
      Offset(cx + 22, cy - 3),
      2.5,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────
// Animated Background — radial gradient orbs that breathe
// ─────────────────────────────────────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  final double t;
  const _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Deep navy base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.background,
    );

    // Primary glow — top centre
    final glowRadius1 = 180.0 + 40.0 * t;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.25),
      glowRadius1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withOpacity(0.18 + 0.06 * t),
            AppColors.primary.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.25),
          radius: glowRadius1,
        )),
    );

    // Accent glow — bottom right
    final glowRadius2 = 150.0 + 30.0 * (1 - t);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      glowRadius2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withOpacity(0.12 + 0.05 * (1 - t)),
            AppColors.accent.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.8, size.height * 0.7),
          radius: glowRadius2,
        )),
    );

    // Small teal accent — bottom left
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.75),
      80.0 + 20.0 * t,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.success.withOpacity(0.08 + 0.03 * t),
            AppColors.success.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.75),
          radius: 80,
        )),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => oldDelegate.t != t;
}

// ─────────────────────────────────────────────────────────────────
// Pulsing dots — 3 dots that animate in sequence
// ─────────────────────────────────────────────────────────────────
class _PulsingDots extends StatelessWidget {
  final AnimationController controller;
  const _PulsingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value + i / 3.0) % 1.0;
            final scale = 0.6 + 0.7 * math.sin(phase * math.pi);
            final opacity = 0.3 + 0.7 * math.sin(phase * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(opacity),
                        AppColors.accent.withOpacity(opacity),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
