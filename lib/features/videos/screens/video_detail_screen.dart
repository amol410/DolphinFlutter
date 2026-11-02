import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/videos_provider.dart';

class VideoDetailScreen extends ConsumerWidget {
  final String videoId;
  const VideoDetailScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoAsync = ref.watch(videoDetailProvider(videoId));

    final isLight = Theme.of(context).brightness == Brightness.light;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return videoAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const ShimmerListLoader(count: 4),
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
              Text('Failed to load video',
                style: GoogleFonts.inter(color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary)),
              TextButton(
                onPressed: () => ref.invalidate(videoDetailProvider(videoId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (video) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              video.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
          ),
          body: Column(
            children: [
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye_outlined,
                              size: 14, color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${video.viewCount} views',
                            style: GoogleFonts.inter(
                              fontSize: 13, color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today_outlined,
                              size: 14, color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(_formatDate(video.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 13, color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary)),
                        ],
                      ),
                      Divider(color: isLight ? AppColors.lightBorder : AppColors.surface2, height: 24),
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
                                fontSize: 11, color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary)),
                            backgroundColor: isLight ? AppColors.lightSurface2 : AppColors.surface2,
                            padding: EdgeInsets.zero,
                            side: BorderSide.none,
                          )).toList(),
                        ),
                      ],
                      if (video.description != null && video.description!.isNotEmpty) ...[
                        Divider(color: isLight ? AppColors.lightBorder : AppColors.surface2, height: 24),
                        Text('Description',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
                          )),
                        const SizedBox(height: 8),
                        Text(video.description!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isLight ? AppColors.lightTextSecondary : AppColors.textSecondary,
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
