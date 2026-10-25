import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../gamification/providers/gamification_provider.dart';

/// Clean 2-Step Onboarding Language Selection Screen
/// Step 1: "What language do you want to learn?" (Target Language: German 🇩🇪 / English 🇬🇧)
/// Step 2: "What is your comfortable language?" (Native Language: English for German; Hindi / Marathi for English)
class LanguageSelectionScreen extends ConsumerStatefulWidget {
  final bool isModal;
  const LanguageSelectionScreen({super.key, this.isModal = false});

  @override
  ConsumerState<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends ConsumerState<LanguageSelectionScreen> {
  int _currentStep = 0; // 0 = Target Language, 1 = Native Language
  String? _selectedTargetLanguage;
  String? _selectedNativeLanguage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  Future<void> _initSelection() async {
    final status = ref.read(gamificationStatusProvider).value;
    if (status != null) {
      if (mounted) {
        setState(() {
          _selectedTargetLanguage = status.targetLanguage;
          _selectedNativeLanguage = status.nativeLanguage;
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedTarget = prefs.getString('active_target_lang') ?? 'de';
      final savedNative = prefs.getString('active_native_lang') ?? (savedTarget == 'en' ? 'hi' : 'en');
      if (mounted) {
        setState(() {
          _selectedTargetLanguage = savedTarget;
          _selectedNativeLanguage = savedNative;
        });
      }
    }
  }

  void _onSelectTarget(String targetLang) {
    setState(() {
      _selectedTargetLanguage = targetLang;
      // Set sensible default native language when target changes
      if (targetLang == 'de') {
        _selectedNativeLanguage = 'en';
      } else if (targetLang == 'en') {
        if (_selectedNativeLanguage != 'hi' && _selectedNativeLanguage != 'mr') {
          _selectedNativeLanguage = 'hi';
        }
      }
      _currentStep = 1; // Advance to Step 2 smoothly
    });
  }

  Future<void> _submitCourse() async {
    if (_selectedTargetLanguage == null || _selectedNativeLanguage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final statusNotifier = ref.read(gamificationStatusProvider.notifier);
      final pathNotifier = ref.read(pathNodesProvider.notifier);

      // 1. Immediately persist user's chosen language to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_target_lang', _selectedTargetLanguage!);
      await prefs.setString('active_native_lang', _selectedNativeLanguage!);
      await prefs.setString('active_level', 'A1');
      await prefs.setBool('has_selected_language_course', true);

      // 2. Configure voice persona
      unawaited(TtsService().setLanguage(_selectedTargetLanguage!).catchError((_) {}));

      // 3. Sequentially update backend user course track first
      await statusNotifier.switchCourse(
        targetLanguage: _selectedTargetLanguage!,
        nativeLanguage: _selectedNativeLanguage!,
        level: 'A1',
      );

      // 4. Load path for this specific language pair
      await pathNotifier.loadPath(
        targetLanguage: _selectedTargetLanguage!,
        nativeLanguage: _selectedNativeLanguage!,
        level: 'A1',
      );

      if (!mounted) return;

      if (widget.isModal) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update language: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131F24), // Sleek Duolingo-dark
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Step Progress and Back Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep == 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                      onPressed: () => setState(() => _currentStep = 0),
                    )
                  else if (widget.isModal)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48),

                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStepDot(isActive: _currentStep == 0, isPassed: _currentStep > 0),
                          const SizedBox(width: 8),
                          _buildStepDot(isActive: _currentStep == 1, isPassed: false),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 48), // Balance spacing
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _currentStep == 0 ? _buildStep1TargetLanguage() : _buildStep2NativeLanguage(),
              ),
            ),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          if (_currentStep == 0) {
                            if (_selectedTargetLanguage != null) {
                              _onSelectTarget(_selectedTargetLanguage!);
                            }
                          } else {
                            _submitCourse();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58CC02), // Duolingo green
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF2B3A42),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _currentStep == 0 ? 'CONTINUE' : 'START LEARNING 🚀',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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

  Widget _buildStepDot({required bool isActive, required bool isPassed}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 28 : 10,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1CB0F6)
            : (isPassed ? const Color(0xFF58CC02) : const Color(0xFF37464F)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ── Step 1: Target Language ──────────────────────────────────────────
  Widget _buildStep1TargetLanguage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        const AnimatedDolphinMascot(
          size: 90,
          pose: MascotPose.waving,
        ),
        const SizedBox(height: 16),
        Text(
          'What would you like to learn?',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your target language course to begin',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 24),

        // German Card
        _buildLanguageCard(
          flag: '🇩🇪',
          title: 'German',
          nativeTitle: 'Deutsch',
          subtitle: 'Complete Goethe A1 Curriculum • 105 Units',
          badge: '105 Units',
          badgeColor: const Color(0xFF1CB0F6),
          isSelected: _selectedTargetLanguage == 'de',
          onTap: () {
            setState(() => _selectedTargetLanguage = 'de');
          },
        ),

        const SizedBox(height: 14),

        // English Card
        _buildLanguageCard(
          flag: '🇬🇧',
          title: 'English',
          nativeTitle: 'English',
          subtitle: 'Fluent Spoken English • Section 1 (35 Units)',
          badge: '35 Units',
          badgeColor: const Color(0xFF58CC02),
          isSelected: _selectedTargetLanguage == 'en',
          onTap: () {
            setState(() => _selectedTargetLanguage = 'en');
          },
        ),
      ],
    );
  }

  // ── Step 2: Native Language ──────────────────────────────────────────
  Widget _buildStep2NativeLanguage() {
    final isGerman = _selectedTargetLanguage == 'de';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        const AnimatedDolphinMascot(
          size: 90,
          pose: MascotPose.reading,
        ),
        const SizedBox(height: 16),
        Text(
          'What is your native language?',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isGerman
              ? 'German A1 is currently instructed through English'
              : 'Choose the language you are most comfortable learning in',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 24),

        if (isGerman) ...[
          // English for German
          _buildLanguageCard(
            flag: '🇬🇧',
            title: 'English',
            nativeTitle: 'English',
            subtitle: 'Instruction, meanings, and tips in English',
            badge: 'Available',
            badgeColor: const Color(0xFF1CB0F6),
            isSelected: _selectedNativeLanguage == 'en',
            onTap: () {
              setState(() => _selectedNativeLanguage = 'en');
            },
          ),
        ] else ...[
          // Hindi for English
          _buildLanguageCard(
            flag: '🇮🇳',
            title: 'Hindi',
            nativeTitle: 'हिन्दी',
            subtitle: 'हिन्दी माध्यम से अंग्रेजी सीखें • 35 Units',
            badge: 'Recommended',
            badgeColor: const Color(0xFFFF9600),
            isSelected: _selectedNativeLanguage == 'hi',
            onTap: () {
              setState(() => _selectedNativeLanguage = 'hi');
            },
          ),

          const SizedBox(height: 14),

          // Marathi for English
          _buildLanguageCard(
            flag: '🇮🇳',
            title: 'Marathi',
            nativeTitle: 'मराठी',
            subtitle: 'मराठी माध्यमातून इंग्रजी शिका • 35 Units',
            badge: 'Popular',
            badgeColor: const Color(0xFF58CC02),
            isSelected: _selectedNativeLanguage == 'mr',
            onTap: () {
              setState(() => _selectedNativeLanguage = 'mr');
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageCard({
    required String flag,
    required String title,
    required String nativeTitle,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F2F38) : const Color(0xFF1A262C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF37464F),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1CB0F6).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Flag Icon Container
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF131F24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF37464F)),
              ),
              child: Text(flag, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 14),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (nativeTitle != title) ...[
                        const SizedBox(width: 6),
                        Text(
                          '($nativeTitle)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // Selection Radio / Checkmark
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF1CB0F6) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF1CB0F6) : const Color(0xFF64748B),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
