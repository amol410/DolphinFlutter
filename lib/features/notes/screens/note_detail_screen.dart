import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/notes_provider.dart';

class NoteDetailScreen extends ConsumerWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailProvider(noteId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;

    return noteAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const ShimmerListLoader(count: 3),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load note',
                style: GoogleFonts.inter(color: textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(noteDetailProvider(noteId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (note) {
        final accentColor = AppColors.noteColorFromString(note.color);
        final bg = Theme.of(context).scaffoldBackgroundColor;
        return Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: bg,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(isDark ? 0.4 : 0.2),
                          bg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  title: Text(
                    note.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metadata card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : const Color(0x060F172A),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (note.subjectName != null)
                                  SubjectBadge(label: note.subjectName!),
                                if (note.topic != null && note.topic!.isNotEmpty)
                                  TopicBadge(label: note.topic!),
                              ],
                            ),
                            if (note.tags.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                children: note.tags
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: surface2Color,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '#$t',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(note.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _contentTypeLabel(note.contentType),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? AppColors.secondary : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (note.isKaraoke) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => context.go('/notes/karaoke/${note.id}', extra: note),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.music_note, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Karaoke & Speaking Practice',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Audio-sync highlighting & voice practice',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Content
                      if (note.contentType == 'html')
                        _HtmlSlideViewer(htmlContent: note.content)
                      else
                        _RichTextContent(htmlContent: note.content),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return 'Updated ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _contentTypeLabel(String type) {
    switch (type) {
      case 'richtext':
        return 'Rich Text';
      case 'docx':
        return 'Word Document';
      case 'html':
        return 'HTML Slide';
      default:
        return type;
    }
  }
}

class _RichTextContent extends StatelessWidget {
  final String htmlContent;
  const _RichTextContent({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(4),
      child: Html(
        data: htmlContent,
        style: {
          'body': Style(
            fontSize: FontSize(15),
            color: onSurface,
            fontFamily: 'Inter',
          ),
          'h1': Style(
            fontSize: FontSize(22),
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
          'h2': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          'h3': Style(
            fontSize: FontSize(16),
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          'code': Style(
            backgroundColor: surface2Color,
            color: AppColors.success,
            fontFamily: 'monospace',
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
          ),
          'pre': Style(
            backgroundColor: surface2Color,
            padding: HtmlPaddings.all(12),
          ),
          'blockquote': Style(
            color: textSecondary,
            fontStyle: FontStyle.italic,
            border: Border(
              left: BorderSide(color: isDark ? AppColors.secondary : AppColors.primary, width: 3),
            ),
            padding: HtmlPaddings.only(left: 12),
          ),
          'a': Style(color: isDark ? AppColors.secondary : AppColors.primary),
          'p': Style(color: onSurface),
          'li': Style(color: onSurface),
        },
      ),
    );
  }
}

class _HtmlSlideViewer extends StatefulWidget {
  final String htmlContent;
  const _HtmlSlideViewer({required this.htmlContent});

  @override
  State<_HtmlSlideViewer> createState() => _HtmlSlideViewerState();
}

class _HtmlSlideViewerState extends State<_HtmlSlideViewer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WebViewWidget(controller: _controller),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FullScreenWebView(htmlContent: widget.htmlContent),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenWebView extends StatefulWidget {
  final String htmlContent;
  const _FullScreenWebView({required this.htmlContent});

  @override
  State<_FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<_FullScreenWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
