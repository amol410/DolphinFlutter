import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/version_check_service.dart';
import 'animated_dolphin_mascot.dart';

class ForceUpdateDialog extends StatelessWidget {
  final VersionCheckResult result;

  const ForceUpdateDialog({
    super.key,
    required this.result,
  });

  static Future<void> show(BuildContext context, VersionCheckResult result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => ForceUpdateDialog(result: result),
    );
  }

  Future<void> _openPlayStore() async {
    try {
      final uri = Uri.parse(result.updateUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mascot with halo glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.4),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const AnimatedDolphinMascot(
                  size: 130,
                  pose: MascotPose.waving,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                result.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle / Version tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Text(
                  'New Version: v${result.latestVersionName}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Message
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 26),

              // Upgrade Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _openPlayStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'UPDATE ON PLAY STORE',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
