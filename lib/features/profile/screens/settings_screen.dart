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
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('API Base URL',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'https://api.dolphincoder.com/api',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save',
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.apiBaseUrlKey, result);
      setState(() => _apiBaseUrl = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restart app to apply new URL'),
              backgroundColor: AppColors.surface2));
      }
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear Cache',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('This will clear cached images. Continue?',
          style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear',
              style: GoogleFonts.inter(
                color: AppColors.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true) {
      PaintingBinding.instance.imageCache.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared'),
              backgroundColor: AppColors.success));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
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
                  title: Text('Push Notifications',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  subtitle: Text('Coming soon',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  value: false,
                  onChanged: null,
                  activeColor: AppColors.primary,
                ),
                const Divider(color: AppColors.surface2, height: 1),
                ListTile(
                  title: Text('Language',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  trailing: Text('English',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
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
              title: Text('API Base URL',
                style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
              subtitle: Text(_apiBaseUrl,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary, size: 18),
              onTap: _editApiUrl,
            ),
          ),
          const SizedBox(height: 20),

          // Cache
          _sectionLabel('Cache'),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.error),
              title: Text('Clear Cache',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                )),
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
                  title: Text('App Version',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  trailing: Text(AppConstants.appVersion,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary)),
                ),
                const Divider(color: AppColors.surface2, height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline,
                      color: AppColors.warning),
                  title: Text('Rate App',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  onTap: () => launchUrl(
                      Uri.parse('https://play.google.com/store')),
                ),
                const Divider(color: AppColors.surface2, height: 1),
                ListTile(
                  title: Text('Privacy Policy',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  onTap: () => launchUrl(
                      Uri.parse('https://dolphincoder.com/privacy')),
                ),
                const Divider(color: AppColors.surface2, height: 1),
                ListTile(
                  title: Text('Terms of Service',
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.white)),
                  onTap: () => launchUrl(
                      Uri.parse('https://dolphincoder.com/terms')),
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
