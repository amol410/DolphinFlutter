import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../providers/notes_provider.dart';
import '../../notes/data/models/note_model.dart';
import '../../../core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _selectedSubjectName = 'All';
  String _selectedTopic = '';
  final _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesListProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (q) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (_searchController.text == q) {
                        ref.read(notesListProvider.notifier).search(q);
                      }
                    });
                  },
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(notesListProvider.notifier).search('');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                // Subject chips
                subjectsAsync.when(
                  loading: () => const SizedBox(height: 36),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subjects) => SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final sel = _selectedSubjectId.isEmpty;
                          return _FilterChip(
                            label: 'All',
                            selected: sel,
                            onTap: () {
                              setState(() {
                                _selectedSubjectId = '';
                                _selectedSubjectName = 'All';
                                _selectedTopic = '';
                              });
                              ref.read(notesListProvider.notifier).filterSubject('');
                            },
                          );
                        }
                        final subject = subjects[i - 1];
                        final sid = subject['_id']?.toString() ?? '';
                        final sel = _selectedSubjectId == sid;
                        return _FilterChip(
                          label: subject['name'] ?? '',
                          selected: sel,
                          onTap: () {
                            setState(() {
                              _selectedSubjectId = sid;
                              _selectedSubjectName = subject['name'] ?? '';
                              _selectedTopic = '';
                            });
                            ref.read(notesListProvider.notifier).filterSubject(sid);
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Topic chips
                if (_selectedSubjectId.isNotEmpty)
                  subjectsAsync.maybeWhen(
                    data: (subjects) {
                      final subject = subjects.firstWhere(
                        (s) => s['_id']?.toString() == _selectedSubjectId,
                        orElse: () => {},
                      );
                      final topics = List<String>.from(subject['topics'] ?? []);
                      if (topics.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: topics.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => _FilterChip(
                              label: topics[i],
                              selected: _selectedTopic == topics[i],
                              isAccent: true,
                              onTap: () {
                                setState(() => _selectedTopic = topics[i]);
                                ref.read(notesListProvider.notifier).filterTopic(topics[i]);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: notesState.isLoading
                ? const ShimmerGridLoader()
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
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            ref.read(notesListProvider.notifier).fetch(refresh: true),
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: notesState.notes.length +
                              (notesState.isLoadingMore ? 2 : 0),
                          itemBuilder: (_, i) {
                            if (i >= notesState.notes.length) {
                              return const ShimmerCard(height: 140);
                            }
                            return _NoteCard(
                              note: notesState.notes[i],
                              onTap: () =>
                                  context.go('/notes/${notesState.notes[i].id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAccent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isAccent ? AppColors.accent : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;

  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.noteColorFromString(note.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.03),
              blurRadius: 12,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Left colored border
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 3, color: color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pin icon
                    if (note.isPinned)
                      Align(
                        alignment: Alignment.topRight,
                        child: Icon(Icons.push_pin,
                          size: 14, color: AppColors.warning),
                      ),
                    Text(
                      note.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Divider(color: color.withOpacity(0.3), thickness: 1),
                    if (note.subjectName != null) ...[
                      SubjectBadge(label: note.subjectName!),
                      const SizedBox(height: 4),
                    ],
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _formatDate(note.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
