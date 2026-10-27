import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/ad_service.dart';
import '../../features/gamification/providers/gamification_provider.dart';
import 'animated_dolphin_mascot.dart';
import 'tactile_game_button.dart';

/// Duolingo-styled Out-of-Oxygen (Hearts depleted) modal sheet.
/// Triggers when the user has 0 bubbles and attempts to start a lesson.
class OutOfOxygenSheet extends ConsumerStatefulWidget {
  final VoidCallback? onRefilled;

  const OutOfOxygenSheet({
    super.key,
    this.onRefilled,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onRefilled}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OutOfOxygenSheet(onRefilled: onRefilled),
    );
  }

  @override
  ConsumerState<OutOfOxygenSheet> createState() => _OutOfOxygenSheetState();
}

class _OutOfOxygenSheetState extends ConsumerState<OutOfOxygenSheet> {
  bool _isLoadingAd = false;
  bool _isSpendingPearls = false;

  void _watchAdToRefill() {
    setState(() => _isLoadingAd = true);

    AdService().showRewardedAd(
      onUserEarnedReward: () async {
        if (!mounted) return;
        setState(() => _isLoadingAd = false);

        await ref.read(gamificationStatusProvider.notifier).claimAdReward('oxygen', 2);

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Ad reward granted! +2 Oxygen bubbles added! 🫧'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onRefilled?.call();
      },
      onAdFailed: (error) {
        if (!mounted) return;
        setState(() => _isLoadingAd = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onAdDismissed: (_) {
        if (mounted) setState(() => _isLoadingAd = false);
      },
    );
  }

  Future<void> _refillWithPearls() async {
    final status = ref.read(gamificationStatusProvider).value;
    final pearls = status?.pearls ?? 0;

    if (pearls < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough pearls (need 50 💎)! Watch a quick video to refill for free 🎬'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSpendingPearls = true);
    final ok = await ref.read(gamificationStatusProvider.notifier).refillOxygen();
    if (!mounted) return;
    setState(() => _isSpendingPearls = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oxygen restored! 🫧 Dive in!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefilled?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(gamificationStatusProvider).value;
    final oxygen = status?.oxygen ?? 0;
    final pearls = status?.pearls ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 18),

          // Echo Mascot in Depleted/Thinking Pose
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withOpacity(0.3),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const AnimatedDolphinMascot(
              size: 110,
              pose: MascotPose.thinking,
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Text(
            'Watch Ad: +2 Oxygen Bubbles',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF38BDF8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Builder(
            builder: (context) {
              final canWatch = AdService().canWatchRewardedAdToday;
              final adsRemaining = AdService().remainingRewardedAdsToday;
              return Text(
                canWatch
                    ? 'Restore +2 bubbles for free without spending pearls ($oxygen/5 currently • $adsRemaining/6 ads left today)'
                    : 'Daily ad limit reached (6/6). Refill with pearls or wait for passive regen ($oxygen/5 currently)',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // 5 Bubble Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      index < oxygen ? Icons.bubble_chart_rounded : Icons.blur_on_rounded,
                      size: 26,
                      color: index < oxygen ? const Color(0xFF38BDF8) : const Color(0xFF64748B).withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$oxygen / 5',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PRIMARY OPT-IN: Watch Rewarded Ad (Free +2 Oxygen Bubbles, max 6/day)
          Builder(
            builder: (context) {
              final canWatch = AdService().canWatchRewardedAdToday;
              return TactileGameButton(
                text: canWatch
                    ? 'WATCH AD: +2 OXYGEN BUBBLES (+2 🫧)'
                    : 'DAILY AD LIMIT REACHED (6/6 TODAY)',
                icon: canWatch ? Icons.play_circle_fill_rounded : Icons.lock_clock_rounded,
                variant: canWatch ? GameButtonVariant.success : GameButtonVariant.outline,
                height: 54,
                fontSize: 15,
                isLoading: _isLoadingAd,
                onPressed: (!canWatch || _isLoadingAd) ? null : _watchAdToRefill,
              );
            },
          ),
          const SizedBox(height: 12),

          // SECONDARY OPT-IN: Pay with Pearls (Cost: 50 Pearls)
          TactileGameButton(
            text: 'REFILL WITH 50 💎 (You have $pearls)',
            icon: Icons.diamond_rounded,
            variant: pearls >= 50 ? GameButtonVariant.primary : GameButtonVariant.outline,
            height: 48,
            fontSize: 14,
            isLoading: _isSpendingPearls,
            onPressed: _isSpendingPearls ? null : _refillWithPearls,
          ),
          const SizedBox(height: 12),

          // DISMISS: Later
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'LATER',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
