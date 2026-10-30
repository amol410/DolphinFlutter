import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../../../shared/widgets/tactile_game_button.dart';
import '../providers/auth_provider.dart';

/// Reusable modal bottom sheet for email OTP verification.
class EmailVerificationSheet extends ConsumerStatefulWidget {
  final String email;
  final String? userName;

  const EmailVerificationSheet({
    super.key,
    required this.email,
    this.userName,
  });

  @override
  ConsumerState<EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends ConsumerState<EmailVerificationSheet> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _onOtpChanged(String value) {
    setState(() => _errorMessage = null);
    if (value.isNotEmpty) {
      HapticFeedback.lightImpact();
    }
    if (value.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).verifyRegistrationOtp(widget.email, otp);
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(true);
        context.go('/language-select');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Verification failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).resendRegistrationOtp(widget.email);
      if (mounted) {
        HapticFeedback.lightImpact();
        _startResendTimer();
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A fresh 6-digit code was sent to ${widget.email}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isResending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not resend OTP. Please try again.';
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0x33FFFFFF) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Floating mascot icon
                const Center(
                  child: AnimatedDolphinMascot(
                    size: 80,
                    pose: MascotPose.reading,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  "We sent a 6-digit confirmation code to:",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 8),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],

                // 6 tactile PIN boxes
                _buildTactilePinInput(isDark),
                const SizedBox(height: 18),

                // Resend countdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                    ),
                    _canResend
                        ? GestureDetector(
                            onTap: _isResending ? null : _resendCode,
                            child: Text(
                              _isResending ? 'Sending...' : 'Resend Code',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Text(
                            'Resend in ${_resendCountdown}s',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 24),

                TactileGameButton(
                  text: 'Verify & Continue',
                  variant: GameButtonVariant.primary,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _verifyOtp,
                ),
                const SizedBox(height: 10),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTactilePinInput(bool isDark) {
    return GestureDetector(
      onTap: () => _otpFocusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: _onOtpChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final text = _otpController.text;
              final hasChar = index < text.length;
              final isFocused = _otpFocusNode.hasFocus &&
                  (index == text.length || (index == 5 && text.length == 6));
              final char = hasChar ? text[index] : '';

              final Color boxBg = isDark
                  ? (hasChar ? const Color(0xFF1E293B) : const Color(0xFF111827))
                  : (hasChar ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC));

              final Color boxBorder = isFocused
                  ? AppColors.primary
                  : (hasChar
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1)));

              final Color bottomBevel = isFocused
                  ? const Color(0xFF0284C7)
                  : (hasChar
                      ? const Color(0xFF059669)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)));

              return SizedBox(
                width: 46,
                height: 56,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: bottomBevel,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: hasChar ? 2 : 0,
                      bottom: hasChar ? 1 : 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: boxBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: boxBorder,
                            width: isFocused ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
