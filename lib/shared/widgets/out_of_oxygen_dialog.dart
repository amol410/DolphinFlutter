import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/ad_service.dart';
import '../../features/auth/providers/auth_provider.dart';
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
  bool _showInsufficientPearlsWarning = false;
  bool _adsUnavailable = false;
  String? _adStatus;
  AdRequestHandle? _adHandle;
  bool _isEmergencyRefilling = false;

  void _watchAdToRefill() {
    setState(() {
      _isLoadingAd = true;
      _showInsufficientPearlsWarning = false;
      _adsUnavailable = false;
      _adStatus = null;
    });

    _adHandle = AdService().showRewardedAd(
      userId: ref.read(authProvider).user?.id ?? '',
      rewardType: 'oxygen',
      onUserEarnedReward: () async {
        final success = await ref
            .read(gamificationStatusProvider.notifier)
            .claimAdReward(rewardType: 'oxygen');

        if (!mounted) return;
        setState(() {
          _isLoadingAd = false;
          _adStatus = null;
        });

        if (success || (ref.read(gamificationStatusProvider).value?.oxygen ?? 0) > 0) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Verified reward: +3 Oxygen bubbles added! 🫧'),
              backgroundColor: Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onRefilled?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not credit reward. Please check your internet connection and try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onAdStatus: (status) {
        if (mounted) setState(() => _adStatus = status);
      },
      onAdFailed: (error) {
        if (!mounted) return;
        setState(() {
          _isLoadingAd = false;
          _adStatus = null;
          if (error == AdService.noAdsAvailableMessage) _adsUnavailable = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onAdDismissed: (_) {
        if (mounted) {
          setState(() {
            _isLoadingAd = false;
            _adStatus = null;
          });
        }
      },
    );
  }

  Future<void> _emergencyRefill() async {
    setState(() => _isEmergencyRefilling = true);
    final res = await ref.read(gamificationStatusProvider.notifier).emergencyRefill();
    if (!mounted) return;
    setState(() => _isEmergencyRefilling = false);

    final messenger = ScaffoldMessenger.of(context);
    if (res != null && res['success'] == true) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Emergency refill: +1 Oxygen bubble 🫧 Keep going!'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefilled?.call();
      return;
    }

    final retryAfter = res?['retryAfterSec'];
    final String text;
    if (retryAfter is num) {
      final mins = (retryAfter / 60).ceil();
      text = 'Emergency refill already used. Available again in ~$mins min. Oxygen also regenerates 1 bubble every 30 min.';
    } else {
      text = 'Could not use emergency refill. Please check your connection and try again.';
    }
    messenger.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _refillWithPearls() async {
    final status = ref.read(gamificationStatusProvider).value;
    final pearls = status?.pearls ?? 0;

    if (pearls < 50) {
      // Clear any pending system snackbars so nothing queues or leaks onto other screens
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() => _showInsufficientPearlsWarning = true);
      return;
    }

    setState(() {
      _isSpendingPearls = true;
      _showInsufficientPearlsWarning = false;
    });
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
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(gamificationStatusProvider).value;
    final oxygen = status?.oxygen ?? 0;
    final pearls = status?.pearls ?? 0;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
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
              const SizedBox(height: 12),

              // Echo Mascot in Depleted/Thinking Pose
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const AnimatedDolphinMascot(
                  size: 92,
                  pose: MascotPose.thinking,
                ),
              ),
              const SizedBox(height: 12),

              // Header Title
              Text(
                'Watch Ad: +3 Oxygen Bubbles',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Builder(
                builder: (context) {
                  final canWatch = AdService().canWatchRewardedAdToday;
                  final adsRemaining = AdService().remainingRewardedAdsToday;
                  return Text(
                    canWatch
                        ? 'Restore +3 bubbles for free without spending pearls ($oxygen/5 currently • $adsRemaining/6 ads left today)'
                        : 'Daily ad limit reached (6/6). Refill with pearls or wait for passive regen ($oxygen/5 currently)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                      height: 1.35,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 5 Bubble Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < oxygen ? Icons.bubble_chart_rounded : Icons.blur_on_rounded,
                          size: 24,
                          color: index < oxygen ? const Color(0xFF38BDF8) : const Color(0xFF64748B).withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$oxygen / 5',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // PRIMARY OPT-IN: Watch Rewarded Ad (Free +3 Oxygen Bubbles, max 6/day)
              Builder(
                builder: (context) {
                  final canWatch = AdService().canWatchRewardedAdToday;
                  return TactileGameButton(
                    text: canWatch
                        ? 'WATCH AD: +3 OXYGEN BUBBLES (+3 🫧)'
                        : 'DAILY AD LIMIT REACHED (6/6 TODAY)',
                    icon: canWatch ? Icons.play_circle_fill_rounded : Icons.lock_clock_rounded,
                    variant: canWatch ? GameButtonVariant.success : GameButtonVariant.outline,
                    height: 50,
                    fontSize: 14,
                    isLoading: _isLoadingAd,
                    onPressed: (!canWatch || _isLoadingAd) ? null : _watchAdToRefill,
                  );
                },
              ),
              if (_isLoadingAd && _adStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  _adStatus!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _adHandle?.cancel();
                    setState(() {
                      _isLoadingAd = false;
                      _adStatus = null;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // LAST RESORT: no ad could be loaded -> capped free +1 oxygen (server: 0 oxygen, 4h cooldown)
              if (_adsUnavailable && oxygen == 0) ...[
                TactileGameButton(
                  text: 'EMERGENCY REFILL: +1 🫧 (FREE, ONCE PER 4H)',
                  icon: Icons.health_and_safety_rounded,
                  variant: GameButtonVariant.primary,
                  height: 46,
                  fontSize: 13,
                  isLoading: _isEmergencyRefilling,
                  onPressed: _isEmergencyRefilling ? null : _emergencyRefill,
                ),
                const SizedBox(height: 10),
              ],

              // In-sheet themed warning banner if insufficient pearls (Suggestion A)
              if (_showInsufficientPearlsWarning) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7F1D1D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.diamond_outlined,
                          size: 18,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Need 50 Pearls (You have $pearls)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap the green button above to refill for free! 🎬',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // SECONDARY OPT-IN: Pay with Pearls (Cost: 50 Pearls)
              TactileGameButton(
                text: 'REFILL WITH 50 💎 (You have $pearls)',
                icon: Icons.diamond_rounded,
                variant: pearls >= 50 ? GameButtonVariant.primary : GameButtonVariant.outline,
                height: 46,
                fontSize: 13,
                isLoading: _isSpendingPearls,
                onPressed: _isSpendingPearls ? null : _refillWithPearls,
              ),
              const SizedBox(height: 8),

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
        ),
      ),
    );
  }
}
