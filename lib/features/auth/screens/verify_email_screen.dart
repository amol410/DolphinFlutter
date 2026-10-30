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

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  final String? userName;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.userName,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
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
    // Auto-submit when all 6 digits have been entered
    if (value.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP code.');
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
            content: Text('A fresh 6-digit verification code was sent to ${widget.email}'),
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
    const Color bg = Color(0xFF0A0F1E);
    const Color cardBg = Color(0xFF111827);
    const Color cyanPrimary = Color(0xFF06B6D4);
    const Color cyanBright = Color(0xFF38BDF8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/register');
            }
          },
        ),
        title: Text(
          'Email Verification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Floating mascot with cyan glow
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            cyanPrimary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AnimatedDolphinMascot(
                      size: 110,
                      pose: MascotPose.reading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Check Your Inbox',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                "We've sent a 6-digit confirmation code to:",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 12),

              // Styled email badge with Edit option
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cyanPrimary.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 16, color: cyanBright),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.email,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/register');
                          }
                        },
                        child: Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cyanBright,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 20),
              ],

              // 6 tactile 3D rounded PIN boxes
              _buildTactilePinInput(),
              const SizedBox(height: 24),

              // 60s resend countdown
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                  ),
                  _canResend
                      ? GestureDetector(
                          onTap: _isResending ? null : _resendCode,
                          child: Text(
                            _isResending ? 'Sending...' : 'Resend Code',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cyanBright,
                            ),
                          ),
                        )
                      : Text(
                          'Resend in ${_resendCountdown}s',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 36),

              // 3D tactile elevation button
              TactileGameButton(
                text: 'Verify & Start Learning 🐬',
                variant: GameButtonVariant.primary,
                height: 54,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _verifyOtp,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTactilePinInput() {
    const double boxWidth = 48;
    const double boxHeight = 60;
    const double depth = 4.0;
    const Color cyanPrimary = Color(0xFF06B6D4);

    return GestureDetector(
      onTap: () => _otpFocusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hidden real textfield
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
          // 6 visual tactile cells
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final text = _otpController.text;
              final hasChar = index < text.length;
              final isFocused = _otpFocusNode.hasFocus &&
                  (index == text.length || (index == 5 && text.length == 6));
              final char = hasChar ? text[index] : '';

              final Color cellBg = hasChar ? const Color(0xFF131D33) : const Color(0xFF0E1424);
              final Color borderColor = isFocused
                  ? cyanPrimary
                  : (hasChar ? const Color(0xFF0891B2) : const Color(0xFF26334D));
              final Color bevelColor = isFocused
                  ? const Color(0xFF0891B2)
                  : (hasChar ? const Color(0xFF065986) : const Color(0xFF1B2438));

              return Container(
                width: boxWidth,
                height: boxHeight,
                decoration: isFocused
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: cyanPrimary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                child: Stack(
                  children: [
                    // 3D bottom base bevel
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: depth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: bevelColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    // Face cell
                    Positioned(
                      left: 0,
                      right: 0,
                      top: hasChar ? 2 : 0,
                      bottom: hasChar ? 2 : depth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cellBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: borderColor,
                            width: isFocused ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
        color: AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
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
                color: const Color(0xFFFCA5A5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
