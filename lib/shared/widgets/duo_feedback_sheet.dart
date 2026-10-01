import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tactile_game_button.dart';

/// Gamified bottom sheet for instant lesson validation.
/// Mint green on correct match, Coral red on incorrect answer.
class DuoFeedbackSheet extends StatelessWidget {
  final bool isSuccess;
  final String title;
  final String? subtitle;
  final String buttonText;
  final VoidCallback onContinue;

  const DuoFeedbackSheet({
    super.key,
    required this.isSuccess,
    this.title = '',
    this.subtitle,
    this.buttonText = 'CONTINUE',
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6);
    final borderColor = isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3);
    final iconColor = isSuccess ? const Color(0xFF059669) : const Color(0xFFE11D48);
    final textColor = isSuccess ? const Color(0xFF065F46) : const Color(0xFF9F1239);

    final displayTitle = title.isNotEmpty
        ? title
        : (isSuccess ? 'Nicely done!' : 'Correct solution:');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isSuccess ? Icons.check_rounded : Icons.close_rounded,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  subtitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor.withOpacity(0.85),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TactileGameButton(
              text: buttonText,
              variant: isSuccess ? GameButtonVariant.success : GameButtonVariant.danger,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}
