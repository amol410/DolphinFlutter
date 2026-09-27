import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/notes_provider.dart';
import '../../notes/data/models/note_model.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';

// Subjects provider (fetches GET /subjects for filter chips)
final subjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = await DioClient.getInstance();
  try {
    final res = await dio.get('/subjects');
    final data = res.data;
    final List list = data is List ? data : (data['subjects'] ?? data['data'] ?? []);
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
});

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _selectedSubjectId = '';
  String _selectedTopic = '';
  final _scrollController = ScrollController();
  final Set<String> _bookmarkedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notesListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleBookmark(String id) {
    setState(() {
      if (_bookmarkedNoteIds.contains(id)) {
        _bookmarkedNoteIds.remove(id);
      } else {
        _bookmarkedNoteIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final notesState = ref.watch(notesListProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'DolphinCoder',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'Notes And Karaoke',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerHigh,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user?.initials ?? 'S',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Rounded-full Search Input
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) {
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (_searchController.text == q) {
                            ref.read(notesListProvider.notifier).search(q);
                          }
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search notes, DOCX & karaoke...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant.withOpacity(0.65),
                        ),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.onSurfaceVariant),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.onSurfaceVariant),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(notesListProvider.notifier).search('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Primary Subject Filter Carousel
                  subjectsAsync.when(
                    loading: () => const SizedBox(height: 38),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (subjects) => SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: subjects.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final isSel = _selectedSubjectId.isEmpty;
                            return _SubjectChip(
                              label: 'All',
                              isSelected: isSel,
                              onTap: () {
                                setState(() {
                                  _selectedSubjectId = '';
                                  _selectedTopic = '';
                                });
                                ref.read(notesListProvider.notifier).filterSubject('');
                              },
                            );
                          }
                          final s = subjects[i - 1];
                          final sid = s['_id']?.toString() ?? '';
                          final isSel = _selectedSubjectId == sid;
                          return _SubjectChip(
                            label: s['name'] ?? '',
                            isSelected: isSel,
                            onTap: () {
                              setState(() {
                                _selectedSubjectId = sid;
                                _selectedTopic = '';
                              });
                              ref.read(notesListProvider.notifier).filterSubject(sid);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Dynamic Secondary Topic Filter Row
                  if (_selectedSubjectId.isNotEmpty)
                    subjectsAsync.maybeWhen(
                      data: (subjects) {
                        final subject = subjects.firstWhere(
                          (s) => s['_id']?.toString() == _selectedSubjectId,
                          orElse: () => {},
                        );
                        final rawTopics = subject['topics'] as List? ?? [];
                        final topics = rawTopics
                            .map((t) => t is Map ? (t['name']?.toString() ?? '') : t.toString())
                            .where((name) => name.trim().isNotEmpty)
                            .toList();

                        if (topics.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: topics.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                if (i == 0) {
                                  return _TopicChip(
                                    label: 'All Topics',
                                    isSelected: _selectedTopic.isEmpty,
                                    onTap: () {
                                      setState(() => _selectedTopic = '');
                                      ref.read(notesListProvider.notifier).filterTopic('');
                                    },
                                  );
                                }
                                final topic = topics[i - 1];
                                return _TopicChip(
                                  label: topic,
                                  isSelected: _selectedTopic == topic,
                                  onTap: () {
                                    setState(() => _selectedTopic = topic);
                                    ref.read(notesListProvider.notifier).filterTopic(topic);
                                  },
                                );
                              },
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Delight Banner: Interactive Audio Notes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.headphones_rounded,
                              size: 22,
                              color: AppColors.onSecondaryFixed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interactive Audio Notes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '2 Karaoke sessions ready today',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'Level A1',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Notes List Feed
            Expanded(
              child: notesState.isLoading
                  ? const ShimmerListLoader()
                  : notesState.notes.isEmpty
                      ? EmptyState(
                          emoji: '📝',
                          title: 'No notes found',
                          subtitle: 'Try a different search or filter',
                          actionLabel: 'Clear filters',
                          onAction: () {
                            _searchController.clear();
                            setState(() {
                              _selectedSubjectId = '';
                              _selectedTopic = '';
                            });
                            ref.read(notesListProvider.notifier).search('');
                          },
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceContainerLowest,
                          onRefresh: () => ref.read(notesListProvider.notifier).fetch(refresh: true),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            physics: const BouncingScrollPhysics(),
                            itemCount: notesState.notes.length + (notesState.isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) {
                              if (i >= notesState.notes.length) {
                                return const ShimmerCard(height: 160);
                              }
                              final note = notesState.notes[i];
                              return _FeedNoteCard(
                                note: note,
                                isBookmarked: _bookmarkedNoteIds.contains(note.id),
                                onToggleBookmark: () => _toggleBookmark(note.id),
                                onTap: () {
                                  if (note.isKaraoke) {
                                    context.go('/notes/karaoke/${note.id}', extra: note);
                                  } else {
                                    context.go('/notes/${note.id}');
                                  }
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      // Ambient Floating Action: Import DOCX / Create Note
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note creation & DOCX import available via Web Portal')),
            );
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Import DOCX / Create Note',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Subject Filter Chip (All, German, Computer Science)
class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Topic Filter Chip (All Topics, A1 Basics, Grammar)
class _TopicChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.secondaryContainer.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// Feed Note Card (matching Google Stitch mockup)
class _FeedNoteCard extends StatelessWidget {
  final NoteModel note;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  const _FeedNoteCard({
    required this.note,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onTap,
  });

  String _formatTimeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return timeago.format(dt);
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewQuote = note.karaokeData?.sentences.firstOrNull?.text ??
        (note.isKaraoke ? '“Guten Morgen! Wie geht es dir?”' : null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin & Tag Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (note.isPinned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📌', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              'Pinned',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (note.subjectName != null && note.subjectName!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          note.subjectName!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (note.topic != null && note.topic!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          note.topic!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSecondaryFixed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Karaoke vs Standard Badge
                if (note.isKaraoke)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 14, color: AppColors.onSecondaryContainer),
                        const SizedBox(width: 3),
                        Text(
                          'Karaoke Note',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 14, color: AppColors.onSurface),
                        const SizedBox(width: 3),
                        Text(
                          'Standard Note',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              note.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),

            // Excerpt
            if (note.content.isNotEmpty)
              Text(
                note.content.replaceAll(RegExp(r'<[^>]*>'), ' ').trim(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            // Visual Preview Graphic for Karaoke
            if (note.isKaraoke && previewQuote != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.isDark ? AppColors.secondary : AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  previewQuote,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Audio sync track • 03:45',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.graphic_eq_rounded, size: 22, color: AppColors.secondaryContainer),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Card Metadata Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 15, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '1.2k views',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeAgo(note.createdAt),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onToggleBookmark,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isBookmarked ? AppColors.secondaryFixed : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 18,
                        color: isBookmarked ? AppColors.onSecondaryFixed : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
