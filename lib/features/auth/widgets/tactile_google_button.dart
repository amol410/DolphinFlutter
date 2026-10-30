import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Crisp multi-color Google 'G' icon painted via Canvas vectors.
class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final Offset centerOffset = Offset(center, center);
    final double strokeWidth = size.width * 0.22;
    final double radius = (size.width - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: centerOffset, radius: radius);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.55, false, paint);

    // Yellow arc (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -math.pi * 1.3, math.pi * 0.55, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.55, false, paint);

    // Blue arc (bottom right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.2, math.pi * 0.45, false, paint);

    // Blue horizontal bar extending from center to right edge
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barHeight = strokeWidth;
    final Rect barRect = Rect.fromLTRB(
      center - 1,
      center - (barHeight / 2),
      size.width,
      center + (barHeight / 2),
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tactile, 3D extruded "Continue with Google" button.
/// Fully adaptive to AMOLED Dark (#000000 / #111116) and Oceanic Light palettes.
class TactileGoogleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;
  final double height;

  const TactileGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.text = 'Continue with Google',
    this.height = 52,
  });

  @override
  State<TactileGoogleButton> createState() => _TactileGoogleButtonState();
}

class _TactileGoogleButtonState extends State<TactileGoogleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    const double depth = 4.0;

    // Theme tokens
    final Color topBg = isDark
        ? const Color(0xFF16161D)
        : Colors.white;
    final Color bevelColor = isDark
        ? const Color(0xFF262633)
        : const Color(0xFFCBD5E1);
    final Color borderColor = isDark
        ? const Color(0x33FFFFFF)
        : const Color(0xFFE2E8F0);
    final Color textColor = isDark
        ? Colors.white
        : const Color(0xFF1E293B);

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) {
              HapticFeedback.lightImpact();
              setState(() => _isPressed = true);
            }
          : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Stack(
          children: [
            // 3D tactile bottom bevel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: isEnabled ? bevelColor : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Depressing top surface
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOutQuad,
              left: 0,
              right: 0,
              top: _isPressed ? depth : 0,
              bottom: _isPressed ? 0 : depth,
              child: Container(
                decoration: BoxDecoration(
                  color: isEnabled
                      ? topBg
                      : (isDark ? const Color(0xFF22222C) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.primary,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GoogleLogoWidget(size: 22),
                            const SizedBox(width: 12),
                            Text(
                              widget.text,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: isEnabled ? textColor : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
