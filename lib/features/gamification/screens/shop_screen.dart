import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/ad_service.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/gamification_provider.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final status = statusAsync.value;
    final pearls = status?.pearls ?? 100;
    final oxygen = status?.oxygen ?? 5;

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
                          'Exchange earned pearls or watch quick sponsor videos for oxygen & boosters.',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFE0F2FE)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ══════════════════════════════════════════════════════════════
            // SECTION 1: DUOLINGO-STYLE FREE REWARDS (SPONSORED ADS)
            // ══════════════════════════════════════════════════════════════
            Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'FREE SPONSORED REWARDS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF059669),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Ad Reward 1: Free +3 Oxygen Bubbles (Max 6 ads/day)
            Builder(
              builder: (context) {
                final canWatchOxygenAd = AdService().canWatchRewardedAdToday;
                final adsRemaining = AdService().remainingRewardedAdsToday;
                return _buildRewardedShopItem(
                  context,
                  icon: '🎬',
                  badge: '+3 BUBBLES',
                  title: 'Watch Ad: +3 Oxygen Bubbles',
                  subtitle: canWatchOxygenAd
                      ? 'Restore +3 bubbles for free without spending pearls ($oxygen/5 currently • $adsRemaining/6 ads left today)'
                      : 'Daily ad limit reached (6/6). Refill with pearls or wait for passive regen ($oxygen/5 currently)',
                  buttonText: oxygen >= 5
                      ? 'FULL'
                      : (!canWatchOxygenAd ? 'MAX (6/6)' : 'WATCH AD'),
                  isActionable: oxygen < 5 && canWatchOxygenAd,
                  buttonColor: const Color(0xFF10B981),
                  shadowColor: const Color(0xFF059669),
                  onWatch: () {
                    AdService().showRewardedAd(
                      userId: ref.read(authProvider).user?.id ?? '',
                      rewardType: 'oxygen',
                      onUserEarnedReward: () async {
                        final success = await ref
                            .read(gamificationStatusProvider.notifier)
                            .claimAdReward(rewardType: 'oxygen');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '🎉 +3 Oxygen bubbles added! 🫧'
                                  : 'Oxygen will update shortly.'),
                              backgroundColor: success ? const Color(0xFF059669) : null,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onAdStatus: (status) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: Text(status),
                              duration: const Duration(seconds: 6),
                              behavior: SnackBarBehavior.floating,
                            ));
                        }
                      },
                      onAdFailed: (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),

            // Ad Reward 2: Free 50 Pearls
            Builder(
              builder: (context) {
                final canWatchPearlAd = AdService().canWatchRewardedAdToday;
                final adsRemaining = AdService().remainingRewardedAdsToday;
                return _buildRewardedShopItem(
                  context,
                  icon: '🎁',
                  badge: 'FREE PEARLS',
                  title: 'Watch Ad: Claim +50 Pearls',
                  subtitle: canWatchPearlAd
                      ? 'Watch a quick 20-second video to claim free pearls for boosters ($adsRemaining/6 ads left today)'
                      : 'Daily ad limit reached (6/6). Come back tomorrow for more free pearls!',
                  buttonText: canWatchPearlAd ? '+50 💎' : 'MAX (6/6)',
                  isActionable: canWatchPearlAd,
                  buttonColor: const Color(0xFF0284C7),
                  shadowColor: const Color(0xFF0369A1),
                  onWatch: () {
                    AdService().showRewardedAd(
                      userId: ref.read(authProvider).user?.id ?? '',
                      rewardType: 'pearls',
                      onUserEarnedReward: () async {
                        final success = await ref
                            .read(gamificationStatusProvider.notifier)
                            .claimAdReward(rewardType: 'pearls');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '🎉 +50 Pearls added! 💎'
                                  : 'Pearls will update shortly.'),
                              backgroundColor: success ? const Color(0xFF059669) : null,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onAdStatus: (status) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: Text(status),
                              duration: const Duration(seconds: 6),
                              behavior: SnackBarBehavior.floating,
                            ));
                        }
                      },
                      onAdFailed: (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // ══════════════════════════════════════════════════════════════
            // SECTION 2: PEARL VAULT
            // ══════════════════════════════════════════════════════════════
            Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'PEARL VAULT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Item 1: Refill Oxygen Bubbles (Paid)
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
              subtitle: (status?.streakFreezeCount ?? 0) > 0
                  ? 'Active protection equipped (${status?.streakFreezeCount} available) — protects your streak if you miss a day'
                  : 'Protects your streak if you miss a day of practice',
              cost: 100,
              canAfford: pearls >= 100,
              buttonText: (status?.streakFreezeCount ?? 0) > 0 ? 'BUY MORE' : 'GET',
              onBuy: () async {
                final res = await ref.read(gamificationStatusProvider.notifier).buyStreakFreeze();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Streak freeze active! 🔥'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            // Item 3: Double XP Potion
            _buildShopItem(
              context,
              icon: '⚡',
              title: 'Double XP Potion',
              subtitle: (status?.isDoubleXpActive ?? false)
                  ? '⚡ 2X XP Boost currently ACTIVE! Complete lessons now to earn double XP'
                  : 'Earn 2x XP points for the next 30 minutes of study',
              cost: 150,
              canAfford: pearls >= 150 && !(status?.isDoubleXpActive ?? false),
              buttonText: (status?.isDoubleXpActive ?? false) ? 'ACTIVE' : 'GET',
              onBuy: () async {
                if (status?.isDoubleXpActive ?? false) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Double XP boost is already active! Go study lessons! ⚡'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final res = await ref.read(gamificationStatusProvider.notifier).buyDoubleXp();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Double XP boost enabled! ⚡'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
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
                if (buttonText != 'FULL' && buttonText != 'ACTIVE') ...[
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

  Widget _buildRewardedShopItem(
    BuildContext context, {
    required String icon,
    required String badge,
    required String title,
    required String subtitle,
    required String buttonText,
    required bool isActionable,
    required Color buttonColor,
    required Color shadowColor,
    required VoidCallback onWatch,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActionable ? buttonColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActionable ? buttonColor.withOpacity(0.08) : const Color(0xFFE2E8F0),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: buttonColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
            onPressed: isActionable ? onWatch : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: isActionable ? 2 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActionable && buttonText != 'FULL') ...[
                  const Icon(Icons.play_circle_fill_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  buttonText,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isActionable ? Colors.white : const Color(0xFF94A3B8),
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
