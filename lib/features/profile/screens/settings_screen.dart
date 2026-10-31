import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../../gamification/widgets/course_selection_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _apiBaseUrl = ApiConstants.defaultBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _apiBaseUrl = prefs.getString(AppConstants.apiBaseUrlKey) ??
            ApiConstants.defaultBaseUrl;
      });
    }
  }

  Future<void> _editApiUrl() async {
    final controller = TextEditingController(text: _apiBaseUrl);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'API Base URL',
          style: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: onSurface, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://api.dolphincoder.com/api',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(
              'Save',
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.apiBaseUrlKey, result);
      setState(() => _apiBaseUrl = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restart app to apply new URL')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will clear cached images and temporary files. Continue?',
          style: GoogleFonts.inter(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Clear',
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      PaintingBinding.instance.imageCache.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account?',
          style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete your profile, progress, pearls, and quiz history. You will be redirected to the account deletion request form.',
          style: GoogleFonts.inter(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Continue to Deletion Form',
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _openUrl(AppConstants.deleteAccountUrl);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final dividerColor = isDark ? const Color(0x1FFFFFFF) : AppColors.lightBorder;

    final statusAsync = ref.watch(gamificationStatusProvider);
    final targetLang = statusAsync.value?.targetLanguage ?? 'de';
    final nativeLang = statusAsync.value?.nativeLanguage ?? (targetLang == 'en' ? 'mr' : 'en');

    String courseLabel = 'German A1 (English instruction)';
    String courseFlag = '🇩🇪';
    if (targetLang == 'en') {
      if (nativeLang == 'mr') {
        courseLabel = 'English A1 (मराठी माध्यम)';
        courseFlag = '🇬🇧';
      } else {
        courseLabel = 'English A1 (हिन्दी माध्यम)';
        courseFlag = '🇬🇧';
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Course & Language Section
          _sectionLabel('Learning & Curriculum'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1CB0F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(courseFlag, style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(
                    'Active Course',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
                  ),
                  subtitle: Text(
                    courseLabel,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => showCourseSelectionSheet(context),
                ),
              ],
            ),
          ),

          // Account & Security
          _sectionLabel('Account'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  title: Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => context.push('/profile/edit'),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B)),
                  title: Text(
                    'Change Password',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => context.push('/profile/password'),
                ),
              ],
            ),
          ),

          // General
          _sectionLabel('General'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
                  title: Text(
                    'Push Notifications',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  subtitle: Text(
                    'Daily streak reminders',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: false,
                  onChanged: null,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // Developer (Only visible in Debug mode)
          if (kDebugMode) ...[
            _sectionLabel('Developer'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.dns_outlined, color: Color(0xFF64748B)),
                title: Text(
                  'API Base URL',
                  style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                ),
                subtitle: Text(
                  _apiBaseUrl,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18),
                onTap: _editApiUrl,
              ),
            ),
          ],

          // Storage & Account Management (Google Play Compliant)
          _sectionLabel('Storage & Data'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF64748B)),
                  title: Text(
                    'Clear Cache',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: _clearCache,
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: Text(
                    'Delete Account',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently delete account and all data',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.error),
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ),

          // About
          _sectionLabel('About'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                  title: Text(
                    'App Version',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: Text(
                    AppConstants.appVersion,
                    style: GoogleFonts.inter(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded, color: AppColors.warning),
                  title: Text(
                    'Rate App',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  onTap: () => _openUrl('https://play.google.com/store/apps/details?id=com.dolphincoder.lms'),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF64748B)),
                  title: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF64748B)),
                  title: Text(
                    'Terms of Service',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _openUrl(AppConstants.termsOfServiceUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log Out Button
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            label: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
