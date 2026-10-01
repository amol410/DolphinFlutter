import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/ocean_status_bar.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../providers/gamification_provider.dart';
import '../data/models/gamification_models.dart';

class ArchipelagoMapScreen extends ConsumerWidget {
  const ArchipelagoMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final pathAsync = ref.watch(pathNodesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Gamified Status Bar with Live User Economy
            statusAsync.when(
              data: (status) => OceanStatusBar(
                flagEmoji: status.targetLanguage == 'de' ? '🇩🇪' : '🇪🇸',
                streakCount: status.streakCount,
                oxygen: status.oxygen,
                maxOxygen: 5,
                pearls: status.pearls,
                onFlagTap: () => _showLanguageSheet(context),
                onOxygenTap: () => context.go('/shop'),
                onPearlsTap: () => context.go('/shop'),
              ),
              loading: () => const OceanStatusBar(
                flagEmoji: '🇩🇪',
                streakCount: 1,
                oxygen: 5,
                pearls: 100,
              ),
              error: (_, __) => const OceanStatusBar(
                flagEmoji: '🇩🇪',
                streakCount: 1,
                oxygen: 5,
                pearls: 100,
              ),
            ),

            // 2. Main Scrollable Archipelago Path
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.read(gamificationStatusProvider.notifier).refresh();
                  ref.read(pathNodesProvider.notifier).loadPath();
                },
                child: pathAsync.when(
                  data: (nodes) {
                    if (nodes.isEmpty) {
                      return const Center(child: Text('Loading islands...'));
                    }
                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        _buildUnitBanner(),
                        const SizedBox(height: 32),
                        for (int i = 0; i < nodes.length; i++)
                          _buildPathNode(context, ref, index: i, node: nodes[i]),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Unable to load path'),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => ref.read(pathNodesProvider.notifier).loadPath(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0284C7),
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UNIT 1 • CORAL REEF',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFBAE6FD),
                  letterSpacing: 1.0,
                ),
              ),
              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Introductions & Daily Greetings',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: const LinearProgressIndicator(
              value: 0.65,
              minHeight: 10,
              backgroundColor: Color(0xFF0369A1),
              valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathNode(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required PathNodeModel node,
  }) {
    final status = node.status;
    final offset = node.offset.abs() > 1.5 ? node.offset.clamp(-65.0, 65.0) : (node.offset * 65.0);
    final isActive = status == 'available';
    final isCompleted = status == 'completed';
    final isChest = node.type == 'chest';
    final isLocked = status == 'locked';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Column(
          children: [
            // Mascot sits on active node with adventure backpack!
            if (isActive) ...[
              const AnimatedDolphinMascot(
                size: 92,
                pose: MascotPose.backpack,
              ),
              const SizedBox(height: 6),
            ],

            // Stepping Stone Node Button
            GestureDetector(
              onTap: () => _handleNodeTap(context, ref, node),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse Ring around active node
                  if (isActive)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF06B6D4).withOpacity(0.2),
                      ),
                    ),

                  // Node Circle Base
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : isActive
                              ? const Color(0xFF06B6D4)
                              : isChest
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFE2E8F0),
                      boxShadow: [
                        BoxShadow(
                          color: isCompleted
                              ? const Color(0xFF059669)
                              : isActive
                                  ? const Color(0xFF0891B2)
                                  : isChest
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFCBD5E1),
                          blurRadius: 0,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 38)
                          : isChest
                              ? const Text('🎁', style: TextStyle(fontSize: 32))
                              : Icon(
                                  isLocked ? Icons.lock_rounded : Icons.star_rounded,
                                  color: isLocked ? const Color(0xFF94A3B8) : Colors.white,
                                  size: 34,
                                ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Node Title Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? const Color(0xFF06B6D4) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: Text(
                node.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? const Color(0xFF0891B2) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNodeTap(BuildContext context, WidgetRef ref, PathNodeModel node) {
    if (node.status == 'locked') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete previous lessons to unlock "${node.title}"!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (node.type == 'chest') {
      // Claim chest bonus
      ref.read(pathNodesProvider.notifier).completeNode(
        node.index,
        stars: 3,
        scorePct: 100,
        xp: node.xpReward,
        pearls: node.pearlsReward > 0 ? node.pearlsReward : 30,
      );
      _showChestDialog(context, node);
      return;
    }

    // Directly launch the interactive lesson challenge tasks screen based on this node
    context.push('/lesson/${node.index}', extra: node);
  }

  void _showChestDialog(BuildContext context, PathNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedDolphinMascot(size: 110, pose: MascotPose.celebrate),
            const SizedBox(height: 12),
            Text(
              'Sunken Treasure Unlocked!',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '+30 Pearls 💎  +20 XP 🔥',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0284C7)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('AWESOME!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Switch Language Course', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🇩🇪', style: TextStyle(fontSize: 28)),
              title: const Text('German (Active)'),
              trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
