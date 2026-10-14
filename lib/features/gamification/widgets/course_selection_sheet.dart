import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/tts_service.dart';
import '../providers/gamification_provider.dart';

class CourseOption {
  final String title;
  final String subtitle;
  final String flag;
  final String targetLanguage;
  final String nativeLanguage;
  final String level;
  final Color accentColor;

  const CourseOption({
    required this.title,
    required this.subtitle,
    required this.flag,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.level = 'A1',
    required this.accentColor,
  });
}

const List<CourseOption> kAvailableCourses = [
  CourseOption(
    title: 'German A1 (Deutsch)',
    subtitle: 'English instruction • Complete 105 Units',
    flag: '🇩🇪',
    targetLanguage: 'de',
    nativeLanguage: 'en',
    level: 'A1',
    accentColor: Color(0xFF1CB0F6),
  ),
  CourseOption(
    title: 'English A1 (इंग्रजी)',
    subtitle: 'मराठी माध्यमातून शिका • Section 1 (35 Units)',
    flag: '🇬🇧',
    targetLanguage: 'en',
    nativeLanguage: 'mr',
    level: 'A1',
    accentColor: Color(0xFF58CC02),
  ),
  CourseOption(
    title: 'English A1 (अंग्रेजी)',
    subtitle: 'हिन्दी माध्यम से सीखें • Section 1 (35 Units)',
    flag: '🇬🇧',
    targetLanguage: 'en',
    nativeLanguage: 'hi',
    level: 'A1',
    accentColor: Color(0xFFFF9600),
  ),
];

/// Displays bottom modal sheet for switching active course track
Future<void> showCourseSelectionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF131F24),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _CourseSelectionContent(),
  );
}

class _CourseSelectionContent extends ConsumerWidget {
  const _CourseSelectionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final currentTarget = statusAsync.value?.targetLanguage ?? 'de';
    final currentNative = statusAsync.value?.nativeLanguage ?? (currentTarget == 'en' ? 'mr' : 'en');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF37464F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.language_rounded, color: Color(0xFF1CB0F6), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Switch Language Course',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select which course track and native language you want to learn with:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            ...kAvailableCourses.map((course) {
              final isSelected = course.targetLanguage == currentTarget &&
                  course.nativeLanguage == currentNative;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () async {
                    if (isSelected) {
                      Navigator.pop(context);
                      return;
                    }

                    final statusNotifier = ref.read(gamificationStatusProvider.notifier);
                    final pathNotifier = ref.read(pathNodesProvider.notifier);

                    Navigator.pop(context);

                    // 1. Voice setup runs quietly in background without blocking UI
                    unawaited(TtsService().setLanguage(course.targetLanguage).catchError((_) {}));

                    // 2. Fire course switch AND path loading at the exact same time in parallel
                    final switchFuture = statusNotifier.switchCourse(
                      targetLanguage: course.targetLanguage,
                      nativeLanguage: course.nativeLanguage,
                      level: course.level,
                    );

                    final pathFuture = pathNotifier.loadPath(
                      targetLanguage: course.targetLanguage,
                      nativeLanguage: course.nativeLanguage,
                      level: course.level,
                    );

                    final results = await Future.wait([switchFuture, pathFuture]);
                    final ok = results[0] as bool;

                    if (ok) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Text(course.flag, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Switched to ${course.title}!',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF0F766E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Failed to switch course. Please try again.'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E2D34) : const Color(0xFF162228),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? course.accentColor : const Color(0xFF2B3A42),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: course.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            course.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    course.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                course.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? course.accentColor : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
