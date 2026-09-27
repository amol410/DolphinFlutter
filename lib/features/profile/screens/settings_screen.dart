import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _apiBaseUrl = ApiConstants.defaultBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiBaseUrl = prefs.getString(AppConstants.apiBaseUrlKey) ??
          ApiConstants.defaultBaseUrl;
    });
  }

  Future<void> _editApiUrl() async {
    final controller = TextEditingController(text: _apiBaseUrl);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
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
      builder: (_) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cache',
          style: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will clear cached images. Continue?',
          style: GoogleFonts.inter(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
            content: Text('Cache cleared'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // General
          _sectionLabel('General'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Push Notifications',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  subtitle: Text(
                    'Coming soon',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: false,
                  onChanged: null,
                  activeColor: AppColors.primary,
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  title: Text(
                    'Language',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: Text(
                    'English',
                    style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Developer
          _sectionLabel('Developer'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
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
          const SizedBox(height: 20),

          // Cache
          _sectionLabel('Cache'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
              title: Text(
                'Clear Cache',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
              onTap: _clearCache,
            ),
          ),
          const SizedBox(height: 20),

          // About
          _sectionLabel('About'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'App Version',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  trailing: Text(
                    AppConstants.appVersion,
                    style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                  ),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline, color: AppColors.warning),
                  title: Text(
                    'Rate App',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  onTap: () => launchUrl(Uri.parse('https://play.google.com/store')),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  title: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  onTap: () => launchUrl(Uri.parse('https://dolphincoder.com/privacy')),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  title: Text(
                    'Terms of Service',
                    style: GoogleFonts.inter(fontSize: 15, color: onSurface),
                  ),
                  onTap: () => launchUrl(Uri.parse('https://dolphincoder.com/terms')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
