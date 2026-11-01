import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/utils/validators.dart';
import 'package:dolphincoder/features/auth/providers/auth_provider.dart';
import 'package:dolphincoder/features/auth/screens/login_screen.dart';
import 'package:dolphincoder/features/auth/widgets/forgot_password_sheet.dart';
import 'package:dolphincoder/shared/widgets/app_text_field.dart';
import 'package:dolphincoder/shared/widgets/tactile_game_button.dart';

/// Mock HTTP Adapter for Dio requests
class MockAuthAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockAuthAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DioClient.reset();
  });

  group('Validators.email Tests', () {
    test('accepts standard valid emails', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('user.name@gmail.com'), isNull);
      expect(Validators.email('learner+1@dolphincoder.org'), isNull);
    });

    test('accepts modern long TLDs and international domains', () {
      expect(Validators.email('student@school.online'), isNull);
      expect(Validators.email('coder@startup.technology'), isNull);
      expect(Validators.email('admin@company.support'), isNull);
      expect(Validators.email('dev@sub.domain.co.in'), isNull);
      expect(Validators.email('HELLO@WORLD.COM'), isNull);
    });

    test('rejects invalid emails', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email('   '), 'Email is required');
      expect(Validators.email('plainaddress'), 'Enter a valid email');
      expect(Validators.email('@missingusername.com'), 'Enter a valid email');
      expect(Validators.email('username@.com'), 'Enter a valid email');
      expect(Validators.email('username@domain'), 'Enter a valid email');
    });
  });

  group('TactileGameButton Widget Tests', () {
    testWidgets('renders button text and responds to tap reliably', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGameButton(
                text: 'Send Verification Code',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);

      await tester.tap(find.byType(TactileGameButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('displays CircularProgressIndicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGameButton(
                text: 'Loading Test',
                isLoading: true,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('LOADING TEST'), findsNothing);
    });

    testWidgets('tap inside SingleChildScrollView does not get swallowed by gesture arena', (tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  TactileGameButton(
                    text: 'Tap Inside ScrollView',
                    onPressed: () => tapCount++,
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TAP INSIDE SCROLLVIEW'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });
  });

  group('ForgotPasswordSheet Full Lifecycle Tests', () {
    testWidgets('Step 1 pre-fills email and renders initial UI', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(initialEmail: 'polyglot@example.com'),
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Registered Email'), findsOneWidget);
      expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
      expect(find.text('polyglot@example.com'), findsOneWidget);
    });

    testWidgets('Step 1 validates email input before triggering request', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(),
            ),
          ),
        ),
      );

      // Tap Send Verification Code without email
      final sendBtn = find.text('SEND VERIFICATION CODE');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);

      // Enter invalid email into email field
      final emailInput = find.descendant(
        of: find.widgetWithText(AppTextField, 'Registered Email'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(emailInput, 'invalid-email');
      await tester.pump();
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('Step 1 dispatches requestPasswordResetOtp and transitions to Step 2', (tester) async {
      bool otpRequested = false;
      String? requestedEmail;

      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        if (options.path.contains(ApiConstants.forgotPassword)) {
          otpRequested = true;
          final body = options.data is String ? jsonDecode(options.data) : options.data;
          requestedEmail = body['email'];
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'message': 'Password reset OTP has been sent to your email address.',
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{"success":false}', 404);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(initialEmail: 'student@school.online'),
            ),
          ),
        ),
      );

      final sendBtn = find.text('SEND VERIFICATION CODE');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(otpRequested, isTrue);
      expect(requestedEmail, 'student@school.online');

      // Verify Step 2 rendered
      expect(find.text('Verify & Reset'), findsOneWidget);
      expect(find.text('Code sent to student@school.online'), findsOneWidget);
      expect(find.text('RESET PASSWORD'), findsOneWidget);
    });

    testWidgets('Step 1 displays error banner when user does not exist', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        if (options.path.contains(ApiConstants.forgotPassword)) {
          return ResponseBody.fromString(
            jsonEncode({
              'success': false,
              'message': 'No account found with this email',
            }),
            404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{"success":false}', 404);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(initialEmail: 'ghost@dolphincoder.com'),
            ),
          ),
        ),
      );

      final sendBtn = find.text('SEND VERIFICATION CODE');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('No account found with this email'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget); // Still on Step 1
    });

    testWidgets('Step 2 completes password reset successfully and pops sheet', (tester) async {
      bool resetCalled = false;
      String? sentOtp;
      String? sentPassword;

      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        if (options.path.contains(ApiConstants.forgotPassword)) {
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'message': 'OTP sent'}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.path.contains(ApiConstants.verifyOtp)) {
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'message': 'OTP verified'}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        if (options.path.contains(ApiConstants.resetPassword)) {
          resetCalled = true;
          final body = options.data is String ? jsonDecode(options.data) : options.data;
          sentOtp = body['otp'];
          sentPassword = body['newPassword'] ?? body['password'];
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'message': 'Password reset successfully'}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{"success":false}', 404);
      });

      bool? sheetResult;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    sheetResult = await showModalBottomSheet<bool>(
                      context: ctx,
                      isScrollControlled: true,
                      builder: (_) => const ForgotPasswordSheet(
                        initialEmail: 'polyglot@example.com',
                      ),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Submit Step 1
      final sendBtn = find.text('SEND VERIFICATION CODE');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Verify & Reset'), findsOneWidget);

      // Enter 6-digit PIN in hidden TextField
      final pinTextField = find.descendant(
        of: find.byType(Stack),
        matching: find.byType(TextField),
      );
      await tester.enterText(pinTextField.first, '123456');
      await tester.pump();

      // Enter New Password
      final newPasswordField = find.descendant(
        of: find.widgetWithText(AppTextField, 'New Password'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(newPasswordField);
      await tester.enterText(newPasswordField, 'SecretPass123!');
      await tester.pump();

      // Enter Confirm Password
      final confirmPasswordField = find.descendant(
        of: find.widgetWithText(AppTextField, 'Confirm New Password'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(confirmPasswordField);
      await tester.enterText(confirmPasswordField, 'SecretPass123!');
      await tester.pumpAndSettle();

      // Tap Reset Password
      final resetBtn = find.text('RESET PASSWORD');
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(sentOtp, '123456');
      expect(sentPassword, 'SecretPass123!');
      expect(sheetResult, isTrue);
    });

    testWidgets('Step 2 validates mismatched passwords', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        if (options.path.contains(ApiConstants.forgotPassword)) {
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'message': 'OTP sent'}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{"success":false}', 404);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(initialEmail: 'match@example.com'),
            ),
          ),
        ),
      );

      final sendBtn = find.text('SEND VERIFICATION CODE');
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Enter 6-digit OTP
      final pinTextField = find.descendant(
        of: find.byType(Stack),
        matching: find.byType(TextField),
      );
      await tester.enterText(pinTextField.first, '654321');
      await tester.pump();

      // Enter mismatched passwords
      final newPasswordField = find.descendant(
        of: find.widgetWithText(AppTextField, 'New Password'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(newPasswordField);
      await tester.enterText(newPasswordField, 'PasswordA');
      await tester.pump();

      final confirmPasswordField = find.descendant(
        of: find.widgetWithText(AppTextField, 'Confirm New Password'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(confirmPasswordField);
      await tester.enterText(confirmPasswordField, 'PasswordB');
      await tester.pumpAndSettle();

      final resetBtn = find.text('RESET PASSWORD');
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsWidgets);
    });
  });

  group('LoginScreen Forgot Password Integration', () {
    testWidgets('Tapping Forgot Password on LoginScreen opens sheet with prefilled email', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Enter email on login screen
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'loginuser@example.com');
      await tester.pumpAndSettle();

      // Tap Forgot Password?
      final forgotBtn = find.text('Forgot Password?');
      await tester.ensureVisible(forgotBtn);
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordSheet), findsOneWidget);
      expect(find.text('loginuser@example.com'), findsWidgets);
    });
  });
}
