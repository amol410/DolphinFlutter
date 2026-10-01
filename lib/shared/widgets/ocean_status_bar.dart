import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top Gamified Status Bar with Country Flag, Streak Fire, Oxygen Energy, and Pearls.
class OceanStatusBar extends StatelessWidget {
  final String flagEmoji;
  final int streakCount;
  final int oxygen;
  final int maxOxygen;
  final int pearls;
  final VoidCallback? onFlagTap;
  final VoidCallback? onStreakTap;
  final VoidCallback? onOxygenTap;
  final VoidCallback? onPearlsTap;

  const OceanStatusBar({
    super.key,
    this.flagEmoji = '🇩🇪',
    this.streakCount = 7,
    this.oxygen = 5,
    this.maxOxygen = 5,
    this.pearls = 420,
    this.onFlagTap,
    this.onStreakTap,
    this.onOxygenTap,
    this.onPearlsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Language Flag Switcher
          GestureDetector(
            onTap: onFlagTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flagEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          // 2. Streak Flame
          GestureDetector(
            onTap: onStreakTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 3),
                Text(
                  '$streakCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),

          // 3. Oxygen Energy Bubbles
          GestureDetector(
            onTap: onOxygenTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bubble_chart_rounded, color: Color(0xFF06B6D4), size: 20),
                const SizedBox(width: 4),
                Text(
                  '$oxygen/$maxOxygen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),
          ),

          // 4. Pearl Balance
          GestureDetector(
            onTap: onPearlsTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.diamond_rounded, color: Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 4),
                Text(
                  '$pearls',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
