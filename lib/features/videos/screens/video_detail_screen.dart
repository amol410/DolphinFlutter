import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/videos_provider.dart';

class VideoDetailScreen extends ConsumerStatefulWidget {
  final String videoId;
  const VideoDetailScreen({super.key, required this.videoId});

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  late final WebViewController _webController;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _playerReady = true),
      ));
  }

  void _loadVideo(String youtubeId) {
    final embedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin:0; padding:0; background:#000; }
    iframe { width:100%; height:100vh; border:none; }
  </style>
</head>
<body>
  <iframe src="https://www.youtube.com/embed/$youtubeId?autoplay=1&rel=0"
    allow="autoplay; encrypted-media" allowfullscreen></iframe>
</body>
</html>''';
    _webController.loadHtmlString(embedHtml);
  }

  @override
  Widget build(BuildContext context) {
    final videoAsync = ref.watch(videoDetailProvider(widget.videoId));

    return videoAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const ShimmerListLoader(count: 4),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load video',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
              TextButton(
                onPressed: () => ref.invalidate(videoDetailProvider(widget.videoId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (video) {
        _loadVideo(video.youtubeVideoId);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // YouTube Player
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: WebViewWidget(controller: _webController),
                  ),
                  // Back button
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Video info
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${video.viewCount} views',
                            style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(_formatDate(video.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      const Divider(color: AppColors.surface2, height: 24),
                      if (video.subjectName != null || video.topic != null)
                        Wrap(
                          spacing: 8,
                          children: [
                            if (video.subjectName != null)
                              SubjectBadge(label: video.subjectName!),
                            if (video.topic != null && video.topic!.isNotEmpty)
                              TopicBadge(label: video.topic!),
                          ],
                        ),
                      if (video.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: video.tags.map((t) => Chip(
                            label: Text('#$t',
                              style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textSecondary)),
                            backgroundColor: AppColors.surface2,
                            padding: EdgeInsets.zero,
                            side: BorderSide.none,
                          )).toList(),
                        ),
                      ],
                      if (video.description != null && video.description!.isNotEmpty) ...[
                        const Divider(color: AppColors.surface2, height: 24),
                        Text('Description',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )),
                        const SizedBox(height: 8),
                        Text(video.description!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          )),
                      ],
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
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
