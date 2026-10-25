import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/screens/language_selection_screen.dart';

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

/// Displays bottom modal sheet for switching active course track with clean 2-step flow
Future<void> showCourseSelectionSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF131F24),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: 600,
        child: LanguageSelectionScreen(isModal: true),
      ),
    ),
  );
}
