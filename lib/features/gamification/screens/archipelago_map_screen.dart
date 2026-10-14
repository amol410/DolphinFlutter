import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/ocean_status_bar.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../providers/gamification_provider.dart';
import '../data/models/gamification_models.dart';
import '../widgets/course_selection_sheet.dart';

class ArchipelagoMapScreen extends ConsumerStatefulWidget {
  const ArchipelagoMapScreen({super.key});

  @override
  ConsumerState<ArchipelagoMapScreen> createState() => _ArchipelagoMapScreenState();
}

class _ArchipelagoMapScreenState extends ConsumerState<ArchipelagoMapScreen> {
  final ScrollController _scrollController = ScrollController();

  int _visibleUnitNumber = 1;
  String _visibleUnitTitle = 'Greet and introduce yourself';
  String _visibleUnitDescription = 'Erste Begrüßungen';
  int _visibleSectionNumber = 1;
  String _visibleSectionTitle = 'Rookie';
  int _visibleSectionUnitNumber = 1;
  Color _visibleUnitColor = const Color(0xFF1CB0F6);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pathAsync = ref.read(pathNodesProvider);
    pathAsync.whenData((nodes) {
      if (nodes.isEmpty) return;

      // Approximate item height: ~130 pixels per node
      final offset = _scrollController.offset.clamp(0.0, double.infinity);
      final estimatedIndex = (offset / 130.0).floor().clamp(0, nodes.length - 1);
      final currentNode = nodes[estimatedIndex];

      if (currentNode.unitNumber != _visibleUnitNumber) {
        setState(() {
          _visibleUnitNumber = currentNode.unitNumber;
          _visibleUnitTitle = currentNode.unitTitle;
          _visibleUnitDescription = currentNode.unitDescription;
          _visibleSectionNumber = currentNode.sectionNumber;
          _visibleSectionTitle = currentNode.sectionTitle;
          _visibleSectionUnitNumber = currentNode.sectionUnitNumber;
          _visibleUnitColor = _parseColor(currentNode.colorHex);
        });
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF1CB0F6);
    }
  }

  void _scrollToActiveNode(List<PathNodeModel> nodes) {
    int activeIndex = nodes.indexWhere((n) => n.status == 'available');
    if (activeIndex == -1) activeIndex = 0;
    final targetOffset = (activeIndex * 130.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToUnit(List<PathNodeModel> nodes, int targetUnit) {
    int unitIndex = nodes.indexWhere((n) => n.unitNumber == targetUnit);
    if (unitIndex == -1) return;
    final targetOffset = (unitIndex * 130.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final pathAsync = ref.watch(pathNodesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131F24), // Sleek Duolingo-dark background
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Gamified Status Bar with Live User Economy
            statusAsync.when(
              data: (status) => OceanStatusBar(
                flagEmoji: status.targetLanguage == 'en' ? '🇬🇧' : (status.targetLanguage == 'de' ? '🇩🇪' : '🇪🇸'),
                streakCount: status.streakCount,
                oxygen: status.oxygen,
                maxOxygen: 5,
                pearls: status.pearls,
                onFlagTap: () => showCourseSelectionSheet(context),
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

            // 2. Dynamic Sticky Section & Unit Banner (Changes Color & Unit on Scroll)
            pathAsync.maybeWhen(
              data: (nodes) {
                if (nodes.isNotEmpty && nodes[0].unitTitle != _visibleUnitTitle) {
                  // Initialize or update with first node whenever course track changes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _visibleUnitNumber = nodes[0].unitNumber;
                        _visibleUnitTitle = nodes[0].unitTitle;
                        _visibleUnitDescription = nodes[0].unitDescription;
                        _visibleSectionNumber = nodes[0].sectionNumber;
                        _visibleSectionTitle = nodes[0].sectionTitle;
                        _visibleSectionUnitNumber = nodes[0].sectionUnitNumber;
                        _visibleUnitColor = _parseColor(nodes[0].colorHex);
                      });
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0.0);
                      }
                    }
                  });
                }
                return _buildDynamicUnitBanner(context, nodes);
              },
              orElse: () => _buildDynamicUnitBanner(context, []),
            ),

            // 3. Main Scrollable Archipelago Path
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      ref.read(gamificationStatusProvider.notifier).refresh();
                      ref.read(pathNodesProvider.notifier).loadPath();
                    },
                    child: pathAsync.when(
                      data: (nodes) {
                        if (nodes.isEmpty) {
                          return const Center(
                            child: Text(
                              'Loading curriculum islands...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                          itemCount: nodes.length,
                          itemBuilder: (context, index) {
                            final node = nodes[index];
                            final isFirstOfUnit = index == 0 || nodes[index - 1].unitNumber != node.unitNumber;

                            return Column(
                              children: [
                                // Duolingo-style Unit Transition Divider
                                if (isFirstOfUnit && index > 0)
                                  _buildUnitDivider(node, () => _scrollToUnit(nodes, node.unitNumber)),
                                _buildPathNode(context, index: index, node: node),
                              ],
                            );
                          },
                        );
                      },
                      loading: () => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF1CB0F6)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Switching course track...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Loading stepping stones & lessons',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Unable to load path', style: TextStyle(color: Colors.white)),
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

                  // Floating Return Button (Scroll to Current Active Node)
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: pathAsync.maybeWhen(
                      data: (nodes) => FloatingActionButton.small(
                        backgroundColor: const Color(0xFF202F36),
                        foregroundColor: const Color(0xFF49C0F8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF37464F), width: 2),
                        ),
                        onPressed: () => _scrollToActiveNode(nodes),
                        child: const Icon(Icons.arrow_upward_rounded, size: 22),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sticky Duolingo Banner with Animated Color & Section/Unit Headings
  Widget _buildDynamicUnitBanner(BuildContext context, List<PathNodeModel> nodes) {
    return GestureDetector(
      onTap: () => _showSectionSelectorSheet(context, nodes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _visibleUnitColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _visibleUnitColor.withValues(alpha: 0.5),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SECTION $_visibleSectionNumber (${_visibleSectionTitle.toUpperCase()}), UNIT $_visibleSectionUnitNumber',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.85), size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _visibleUnitTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_visibleUnitDescription.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _visibleUnitDescription,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
              tooltip: 'Unit Guidebook',
              onPressed: () => _showGuidebookSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  // Unit Divider with optional 'JUMP HERE?' button
  Widget _buildUnitDivider(PathNodeModel node, VoidCallback onJump) {
    final unitColor = _parseColor(node.colorHex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFF273840), thickness: 2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '— ${node.unitTitle} —',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFF273840), thickness: 2)),
            ],
          ),
          if (node.status == 'locked') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onJump,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: unitColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: unitColor.withValues(alpha: 0.4),
                      blurRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'JUMP HERE?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Stepping Stone Node Button
  Widget _buildPathNode(
    BuildContext context, {
    required int index,
    required PathNodeModel node,
  }) {
    final status = node.status;
    final offset = node.offset.abs() > 1.5 ? node.offset.clamp(-65.0, 65.0) : (node.offset * 65.0);
    final isActive = status == 'available';
    final isCompleted = status == 'completed';
    final isChest = node.type == 'chest';
    final isLocked = status == 'locked';
    final nodeColor = _parseColor(node.colorHex);

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
              onTap: () => _handleNodeTap(context, node),
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
                        color: nodeColor.withValues(alpha: 0.25),
                      ),
                    ),

                  // Node Circle Base
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF58CC02)
                          : isActive
                              ? nodeColor
                              : isChest
                                  ? const Color(0xFFFF9600)
                                  : const Color(0xFF273840),
                      boxShadow: [
                        BoxShadow(
                          color: isCompleted
                              ? const Color(0xFF46A302)
                              : isActive
                                  ? nodeColor.withValues(alpha: 0.7)
                                  : isChest
                                      ? const Color(0xFFCC7800)
                                      : const Color(0xFF1B272C),
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
                                  color: isLocked ? const Color(0xFF52656D) : Colors.white,
                                  size: 34,
                                ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Node Title Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B272C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? nodeColor : const Color(0xFF37464F),
                  width: 1.5,
                ),
              ),
              child: Text(
                node.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNodeTap(BuildContext context, PathNodeModel node) {
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

    context.push('/lesson/${node.index}', extra: node).then((_) {
      ref.read(pathNodesProvider.notifier).loadPath();
    });
  }

  // Section Selector Modal Sheet (Section 1: Rookie, Section 2: Explorer, Section 3: Traveler)
  void _showSectionSelectorSheet(BuildContext context, List<PathNodeModel> nodes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B272C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF37464F),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'German A1 Course Sections',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '3 Sections • 105 Units • 1,680 Lessons',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTile(
              sectionNum: 1,
              title: 'Section 1: Rookie',
              subtitle: 'Units 1–35 • First Steps & Foundations',
              color: const Color(0xFF1CB0F6),
              isCurrent: _visibleSectionNumber == 1,
              onTap: () {
                Navigator.pop(ctx);
                _scrollToUnit(nodes, 1);
              },
            ),
            const SizedBox(height: 12),
            _buildSectionTile(
              sectionNum: 2,
              title: 'Section 2: Explorer',
              subtitle: 'Units 1–35 (36–70) • Daily Life & Travel',
              color: const Color(0xFF58CC02),
              isCurrent: _visibleSectionNumber == 2,
              onTap: () {
                Navigator.pop(ctx);
                _scrollToUnit(nodes, 36);
              },
            ),
            const SizedBox(height: 12),
            _buildSectionTile(
              sectionNum: 3,
              title: 'Section 3: Traveler',
              subtitle: 'Units 1–35 (71–105) • Fluency & Goethe A1 Exam',
              color: const Color(0xFFFF9600),
              isCurrent: _visibleSectionNumber == 3,
              onTap: () {
                Navigator.pop(ctx);
                _scrollToUnit(nodes, 71);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile({
    required int sectionNum,
    required String title,
    required String subtitle,
    required Color color,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent ? color.withValues(alpha: 0.15) : const Color(0xFF273840),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrent ? color : const Color(0xFF37464F),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$sectionNum',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // Unit Guidebook Modal Sheet
  void _showGuidebookSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B272C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF37464F),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Color(0xFF1CB0F6), size: 26),
                const SizedBox(width: 10),
                Text(
                  'Unit $_visibleUnitNumber Guidebook',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _visibleUnitTitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: _visibleUnitColor),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF273840),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Key German Concepts',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'In this unit, practice essential phrases and grammar patterns. Pay close attention to word order and verb endings.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _visibleUnitColor,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('GOT IT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChestDialog(BuildContext context, PathNodeModel node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B272C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedDolphinMascot(size: 110, pose: MascotPose.celebrate),
            const SizedBox(height: 12),
            Text(
              'Sunken Treasure Unlocked!',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '+${node.pearlsReward} Pearls 💎  +${node.xpReward} XP 🔥',
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
}
