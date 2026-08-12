import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user?.initials ?? 'DC',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.name ?? 'User',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  _RoleBadge(role: user?.role ?? 'student'),
                ],
              ),
            ),

            // Stats row
            GlassCard(
              child: Row(
                children: [
                  _StatSection(value: '0', label: 'Quizzes'),
                  _Divider(),
                  _StatSection(value: '0', label: 'Passed'),
                  _Divider(),
                  _StatSection(value: '0', label: 'Decks'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Menu
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () => context.go('/profile/edit'),
                  ),
                  const Divider(color: AppColors.surface2, height: 1),
                  _MenuItem(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onTap: () => context.go('/profile/password'),
                  ),
                  const Divider(color: AppColors.surface2, height: 1),
                  _MenuItem(
                    icon: Icons.video_library_outlined,
                    label: 'Videos',
                    onTap: () => context.go('/videos'),
                  ),
                  const Divider(color: AppColors.surface2, height: 1),
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.go('/settings'),
                  ),
                  const Divider(color: AppColors.surface2, height: 1),
                  _MenuItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    iconColor: AppColors.error,
                    labelColor: AppColors.error,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ),

            // Version
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Logout',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to logout?',
          style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout',
              style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case 'admin': color = AppColors.warning; break;
      case 'trainer': color = AppColors.noteBlue; break;
      default: color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  final String value;
  final String label;
  const _StatSection({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.surface2);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.primary,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                )),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
