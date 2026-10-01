import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../providers/gamification_provider.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final pearls = statusAsync.value?.pearls ?? 100;
    final oxygen = statusAsync.value?.oxygen ?? 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Nautical Shop',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(
                  '$pearls',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Shop Mascot Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const AnimatedDolphinMascot(size: 72, pose: MascotPose.celebrate),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEARL BAZAAR',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exchange earned pearls for oxygen refills and streak boosters.',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFE0F2FE)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Item 1: Refill Oxygen Bubbles
            _buildShopItem(
              context,
              icon: '🫧',
              title: 'Refill Oxygen Bubbles',
              subtitle: 'Restore full 5 oxygen bubbles instantly ($oxygen/5 currently)',
              cost: 50,
              canAfford: pearls >= 50 && oxygen < 5,
              buttonText: oxygen >= 5 ? 'FULL' : 'REFILL',
              onBuy: () async {
                final ok = await ref.read(gamificationStatusProvider.notifier).refillOxygen();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Oxygen fully restored! 🫧' : 'Failed to refill oxygen'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            // Item 2: Streak Freeze
            _buildShopItem(
              context,
              icon: '🧊',
              title: 'Streak Freeze',
              subtitle: 'Protects your streak if you miss a day of practice',
              cost: 100,
              canAfford: pearls >= 100,
              buttonText: 'GET',
              onBuy: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Streak freeze active! 🔥'), behavior: SnackBarBehavior.floating),
                );
              },
            ),

            // Item 3: Double XP Potion
            _buildShopItem(
              context,
              icon: '⚡',
              title: 'Double XP Potion',
              subtitle: 'Earn 2x XP points for the next 30 minutes of study',
              cost: 150,
              canAfford: pearls >= 150,
              buttonText: 'GET',
              onBuy: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Double XP boost enabled! ⚡'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required int cost,
    required bool canAfford,
    required String buttonText,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0xFFE2E8F0), blurRadius: 0, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: canAfford ? onBuy : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: canAfford ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
                if (buttonText != 'FULL') ...[
                  const SizedBox(width: 4),
                  const Text('💎', style: TextStyle(fontSize: 12)),
                  Text(
                    '$cost',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
