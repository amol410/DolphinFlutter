import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/quiz_model.dart';

class MatchPairsWidget extends StatefulWidget {
  final QuizQuestion question;
  final List<Map<String, String>> currentMatches;
  final ValueChanged<List<Map<String, String>>> onMatchesChanged;
  final bool readOnly;

  const MatchPairsWidget({
    super.key,
    required this.question,
    required this.currentMatches,
    required this.onMatchesChanged,
    this.readOnly = false,
  });

  @override
  State<MatchPairsWidget> createState() => _MatchPairsWidgetState();
}

class _MatchPairsWidgetState extends State<MatchPairsWidget> {
  String? _selectedLeft;
  late List<String> _leftItems;
  late List<String> _shuffledRightItems;
  final Map<String, String> _pairsMap = {};

  static const List<Color> _pairColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(covariant MatchPairsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _selectedLeft = null;
      _initData();
    }
  }

  void _initData() {
    final q = widget.question;
    if (q.leftItems.isNotEmpty) {
      _leftItems = List.from(q.leftItems);
    } else if (q.pairs.isNotEmpty) {
      _leftItems = q.pairs.map((p) => p.left).toList();
    } else {
      _leftItems = [];
    }

    List<String> rawRight;
    if (q.rightItems.isNotEmpty) {
      rawRight = List.from(q.rightItems);
    } else if (q.pairs.isNotEmpty) {
      rawRight = q.pairs.map((p) => p.right).toList();
    } else {
      rawRight = [];
    }

    // Derange / shuffle right items if needed
    _shuffledRightItems = List.from(rawRight);
    if (_shuffledRightItems.length > 1 && q.rightItems.isEmpty) {
      _shuffledRightItems.shuffle();
    }

    _pairsMap.clear();
    for (final item in widget.currentMatches) {
      final l = item['left'];
      final r = item['right'];
      if (l != null && r != null && l.isNotEmpty && r.isNotEmpty) {
        _pairsMap[l] = r;
      }
    }
  }

  void _emitChange() {
    final result = _leftItems.map((left) {
      return {
        'left': left,
        'right': _pairsMap[left] ?? '',
      };
    }).toList();
    widget.onMatchesChanged(result);
  }

  void _onLeftTap(String leftText) {
    if (widget.readOnly) return;
    setState(() {
      if (_selectedLeft == leftText) {
        _selectedLeft = null; // deselect
      } else {
        _selectedLeft = leftText;
      }
    });
  }

  void _onRightTap(String rightText) {
    if (widget.readOnly) return;
    final selected = _selectedLeft;
    if (selected == null) {
      // Find if right is already paired and highlight its left
      final pairedLeft = _pairsMap.entries
          .firstWhere((e) => e.value == rightText, orElse: () => const MapEntry('', ''))
          .key;
      if (pairedLeft.isNotEmpty) {
        setState(() => _selectedLeft = pairedLeft);
      }
      return;
    }

    setState(() {
      // Remove any existing pairing that uses this rightText
      _pairsMap.removeWhere((_, r) => r == rightText);
      // Pair selected left with this rightText
      _pairsMap[selected] = rightText;
      _selectedLeft = null; // reset selection
    });
    _emitChange();
  }

  void _unpair(String leftText) {
    if (widget.readOnly) return;
    setState(() {
      _pairsMap.remove(leftText);
      if (_selectedLeft == leftText) _selectedLeft = null;
    });
    _emitChange();
  }

  void _resetAll() {
    if (widget.readOnly) return;
    setState(() {
      _pairsMap.clear();
      _selectedLeft = null;
    });
    _emitChange();
  }

  Color _getColorForLeft(int index) {
    return _pairColors[index % _pairColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    final pairedCount = _leftItems.where((l) => (_pairsMap[l] ?? '').isNotEmpty).length;
    final totalCount = _leftItems.length;
    final isComplete = totalCount > 0 && pairedCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper badge / progress bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isComplete ? AppColors.success.withOpacity(0.4) : borderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.swap_horiz_rounded,
                size: 18,
                color: isComplete ? AppColors.success : (isDark ? AppColors.secondary : AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.readOnly
                      ? 'Matched pairs view'
                      : isComplete
                          ? 'All pairs matched! ($pairedCount/$totalCount)'
                          : 'Tap a prompt on the left, then tap its match on the right',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
                    color: isComplete ? AppColors.success : textSecondary,
                  ),
                ),
              ),
              if (!widget.readOnly && pairedCount > 0)
                TextButton(
                  onPressed: _resetAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Side-by-side columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Prompts Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'PROMPTS (${_leftItems.length})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                  ),
                  ..._leftItems.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final leftText = entry.value;
                    final isSelected = _selectedLeft == leftText;
                    final pairedRight = _pairsMap[leftText];
                    final isPaired = pairedRight != null && pairedRight.isNotEmpty;
                    final color = _getColorForLeft(idx);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _onLeftTap(leftText),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.18)
                                  : isPaired
                                      ? color.withOpacity(0.08)
                                      : surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : isPaired
                                        ? color.withOpacity(0.6)
                                        : borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isPaired ? color : surface2Color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isPaired ? Colors.white : textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isPaired && !widget.readOnly)
                                      GestureDetector(
                                        onTap: () => _unpair(leftText),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: isDark ? Colors.white60 : Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  leftText,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                                    color: onSurface,
                                  ),
                                ),
                                if (isPaired) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '↔ $pairedRight',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Answers Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'MATCHES',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  ..._shuffledRightItems.map((rightText) {
                    final pairedLeft = _pairsMap.entries
                        .firstWhere((e) => e.value == rightText, orElse: () => const MapEntry('', ''))
                        .key;
                    final isPaired = pairedLeft.isNotEmpty;
                    final leftIndex = isPaired ? _leftItems.indexOf(pairedLeft) : -1;
                    final color = leftIndex >= 0 ? _getColorForLeft(leftIndex) : (isDark ? AppColors.secondary : AppColors.primary);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _onRightTap(rightText),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isPaired
                                  ? color.withOpacity(0.12)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPaired ? color.withOpacity(0.7) : borderColor,
                                width: isPaired ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isPaired)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Item ${leftIndex + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    else
                                      Icon(Icons.link, size: 14, color: textMuted),
                                    const Spacer(),
                                    if (isPaired)
                                      Icon(Icons.check, size: 14, color: color),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rightText,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
