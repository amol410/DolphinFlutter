import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum GameButtonVariant { primary, secondary, success, danger, outline }

/// Tactile 3D-styled button inspired by gamified language apps.
/// Features a prominent bottom border shadow that physically depresses on tap.
class TactileGameButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final double height;
  final double? width;
  final double fontSize;
  final bool isLoading;

  const TactileGameButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.height = 52,
    this.width,
    this.fontSize = 15,
    this.isLoading = false,
  });

  @override
  State<TactileGameButton> createState() => _TactileGameButtonState();
}

class _TactileGameButtonState extends State<TactileGameButton> {
  bool _isPressed = false;

  (Color bg, Color shadow, Color text) _getColors() {
    switch (widget.variant) {
      case GameButtonVariant.primary:
        return (const Color(0xFF06B6D4), const Color(0xFF0891B2), Colors.white);
      case GameButtonVariant.secondary:
        return (const Color(0xFF6366F1), const Color(0xFF4F46E5), Colors.white);
      case GameButtonVariant.success:
        return (const Color(0xFF10B981), const Color(0xFF059669), Colors.white);
      case GameButtonVariant.danger:
        return (const Color(0xFFF43F5E), const Color(0xFFE11D48), Colors.white);
      case GameButtonVariant.outline:
        return (Colors.white, const Color(0xFFE2E8F0), const Color(0xFF475569));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    const double depth = 4.0;
    final baseColor = isEnabled ? colors.$2 : const Color(0xFF94A3B8);
    final topColor = isEnabled ? colors.$1 : const Color(0xFFCBD5E1);

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height,
        child: Stack(
          children: [
            // 3D bottom base (the tactile lip / extrusion)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: depth,
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Surface button that depresses down
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOutQuad,
              left: 0,
              right: 0,
              top: _isPressed ? depth : 0,
              bottom: _isPressed ? 0 : depth,
              child: Container(
                decoration: BoxDecoration(
                  color: topColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.variant == GameButtonVariant.outline
                        ? const Color(0xFFCBD5E1)
                        : Colors.white.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: colors.$3, size: widget.fontSize + 4),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: widget.fontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isEnabled ? colors.$3 : const Color(0xFF64748B),
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
