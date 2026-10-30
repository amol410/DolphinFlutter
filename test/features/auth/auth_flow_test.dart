import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/features/auth/data/auth_repository.dart';
import 'package:dolphincoder/features/auth/data/models/user_model.dart';
import 'package:dolphincoder/features/auth/providers/auth_provider.dart';
import 'package:dolphincoder/features/auth/screens/login_screen.dart';
import 'package:dolphincoder/features/auth/screens/register_screen.dart';
import 'package:dolphincoder/features/auth/screens/verify_email_screen.dart';
import 'package:dolphincoder/features/auth/widgets/email_verification_sheet.dart';
import 'package:dolphincoder/features/auth/widgets/forgot_password_sheet.dart';
import 'package:dolphincoder/features/auth/widgets/tactile_google_button.dart';

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

/// Fake GoogleSignInAccount for testing
class FakeGoogleSignInAccount implements GoogleSignInAccount {
  @override
  final String email;
  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? photoUrl;
  @override
  final String? serverAuthCode;

  FakeGoogleSignInAccount({
    required this.email,
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.serverAuthCode,
  });

  @override
  Future<GoogleSignInAuthentication> get authentication =>
      Future.value(FakeGoogleSignInAuthentication());

  @override
  Future<Map<String, String>> get authHeaders =>
      Future.value({'Authorization': 'Bearer fake_token'});

  @override
  Future<void> clearAuthCache() async {}
}

class FakeGoogleSignInAuthentication implements GoogleSignInAuthentication {
  @override
  String? get accessToken => 'mock_google_access_token_123';

  @override
  String? get idToken => 'mock_google_id_token_456';

  @override
  String? get serverAuthCode => null;
}

/// Fake GoogleSignIn
class FakeGoogleSignIn implements GoogleSignIn {
  final bool shouldCancel;

  FakeGoogleSignIn({this.shouldCancel = false});

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (shouldCancel) return null;
    return FakeGoogleSignInAccount(
      email: 'oceanlearner@example.com',
      id: 'google_user_999',
      displayName: 'Ocean Learner',
      photoUrl: 'https://example.com/avatar.png',
    );
  }

  @override
  GoogleSignInAccount? get currentUser => null;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => const Stream.empty();

  @override
  Future<GoogleSignInAccount?> signInSilently({bool reAuthenticate = false, bool suppressErrors = true}) =>
      signIn();

  @override
  Future<GoogleSignInAccount?> disconnect() async => null;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<bool> requestScopes(List<String> scopes) async => true;

  @override
  bool get forceCodeForRefreshToken => false;

  @override
  String? get hostedDomain => null;

  @override
  List<String> get scopes => ['email', 'profile'];

  @override
  SignInOption get signInOption => SignInOption.standard;

  @override
  String? get clientId => null;

  @override
  String? get serverClientId => null;

  @override
  String? get forceAccountName => null;

  @override
  Future<bool> canAccessScopes(List<String> scopes, {String? accessToken}) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DioClient.reset();
  });

  group('AuthRepository Unit Tests', () {
    test('requestPasswordResetOtp sends email to /auth/forgot-password', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'OTP sent'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      await repo.requestPasswordResetOtp('test@dolphincoder.com');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.forgotPassword));
      expect(recordedOptions!.data, equals({'email': 'test@dolphincoder.com'}));
    });

    test('verifyOtp sends email & otp to /auth/verify-otp', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'OTP verified successfully'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      await repo.verifyOtp('test@dolphincoder.com', '654321');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.verifyOtp));
      expect(recordedOptions!.data, equals({'email': 'test@dolphincoder.com', 'otp': '654321'}));
    });

    test('resetPassword sends email, otp & newPassword to /auth/reset-password', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Password has been updated'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      await repo.resetPassword('test@dolphincoder.com', '654321', 'SuperSecret99');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.resetPassword));
      final mapData = recordedOptions!.data as Map<String, dynamic>;
      expect(mapData['email'], equals('test@dolphincoder.com'));
      expect(mapData['otp'], equals('654321'));
      expect(mapData['newPassword'], equals('SuperSecret99'));
    });

    test('signInWithGoogle completes backend call, persists token & user', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'token': 'jwt_backend_token_xyz',
            'user': {
              '_id': 'user_google_1',
              'name': 'Ocean Learner',
              'email': 'oceanlearner@example.com',
              'role': 'student',
              'avatar': 'https://example.com/avatar.png',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final fakeGoogleSignIn = FakeGoogleSignIn();
      final repo = AuthRepository(googleSignIn: fakeGoogleSignIn);

      final result = await repo.signInWithGoogle();

      expect(result, isNotNull);
      expect(result!['token'], equals('jwt_backend_token_xyz'));
      final user = result['user'] as UserModel;
      expect(user.id, equals('user_google_1'));
      expect(user.email, equals('oceanlearner@example.com'));

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.googleLogin));
      final payload = recordedOptions!.data as Map<String, dynamic>;
      expect(payload['email'], equals('oceanlearner@example.com'));
      expect(payload['idToken'], equals('mock_google_id_token_456'));
      expect(payload['accessToken'], equals('mock_google_access_token_123'));

      // Verify token was stored
      final token = await repo.getToken();
      expect(token, equals('jwt_backend_token_xyz'));
    });

    test('signInWithGoogle returns null if user cancels dialog', () async {
      final fakeGoogleSignIn = FakeGoogleSignIn(shouldCancel: true);
      final repo = AuthRepository(googleSignIn: fakeGoogleSignIn);

      final result = await repo.signInWithGoogle();
      expect(result, isNull);
    });

    test('register with requireVerification returns verification payload without token', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'requireVerification': true,
            'message': 'Please verify your email with the 6-digit OTP code sent.',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      final res = await repo.register('New User', 'newuser@dolphincoder.com', 'Secret123');

      expect(res['requireVerification'], isTrue);
      expect(res['email'], equals('newuser@dolphincoder.com'));
      final token = await repo.getToken();
      expect(token, isNull);
    });

    test('verifyRegistrationOtp calls endpoint, saves token & user session', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'token': 'verified_reg_jwt_777',
            'user': {
              '_id': 'user_verified_1',
              'name': 'Verified Dolphin',
              'email': 'verified@dolphincoder.com',
              'role': 'student',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      final res = await repo.verifyRegistrationOtp('verified@dolphincoder.com', '123456');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.verifyRegistrationOtp));
      expect(recordedOptions!.data, equals({'email': 'verified@dolphincoder.com', 'otp': '123456'}));

      expect(res['token'], equals('verified_reg_jwt_777'));
      expect((res['user'] as UserModel).name, equals('Verified Dolphin'));

      final token = await repo.getToken();
      expect(token, equals('verified_reg_jwt_777'));
    });

    test('resendRegistrationOtp calls endpoint with email', () async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'New OTP sent'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      await repo.resendRegistrationOtp('resend@dolphincoder.com');

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.resendRegistrationOtp));
      expect(recordedOptions!.data, equals({'email': 'resend@dolphincoder.com'}));
    });
  });

  group('AuthController / AuthNotifier State Provider Tests', () {
    test('signInWithGoogle updates state with authenticated user', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'token': 'jwt_google_user',
            'user': {
              '_id': 'google_123',
              'name': 'Dolphin Coder',
              'email': 'dolphin@test.com',
              'role': 'student',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository(googleSignIn: FakeGoogleSignIn());
      final controller = AuthController(repo);

      expect(controller.state.user, isNull);
      await controller.signInWithGoogle();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.user, isNotNull);
      expect(controller.state.user!.name, equals('Dolphin Coder'));
      expect(controller.state.user!.email, equals('dolphin@test.com'));
    });

    test('requestPasswordResetOtp sets loading and completes without error', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'success': true}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final repo = AuthRepository();
      final controller = AuthController(repo);

      await controller.requestPasswordResetOtp('ocean@learn.com');
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
    });

    test('verifyOtp and resetPassword complete successfully', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'success': true}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final repo = AuthRepository();
      final controller = AuthController(repo);

      await controller.verifyOtp('ocean@learn.com', '123456');
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);

      await controller.resetPassword('ocean@learn.com', '123456', 'MyNewPassword#1');
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
    });

    test('verifyRegistrationOtp updates state with verified user', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'token': 'verified_reg_jwt_999',
            'user': {
              '_id': 'user_verified_999',
              'name': 'Verified Polyglot',
              'email': 'verified@test.com',
              'role': 'student',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repo = AuthRepository();
      final controller = AuthController(repo);

      expect(controller.state.user, isNull);
      await controller.verifyRegistrationOtp('verified@test.com', '654321');

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.user, isNotNull);
      expect(controller.state.user!.name, equals('Verified Polyglot'));
    });

    test('resendRegistrationOtp completes cleanly', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'success': true}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final repo = AuthRepository();
      final controller = AuthController(repo);

      await controller.resendRegistrationOtp('verified@test.com');
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
    });
  });

  group('TactileGoogleButton Widget Tests', () {
    testWidgets('renders Google logo and text', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGoogleButton(
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogoWidget), findsOneWidget);

      await tester.tap(find.byType(TactileGoogleButton));
      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGoogleButton(
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });
  });

  group('ForgotPasswordSheet Interactive Modal Tests', () {
    testWidgets('renders Step 1 and validates email', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('SEND VERIFICATION CODE'), findsOneWidget);

      // Attempt to tap without entering email
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('advances to Step 2 when email is submitted', (WidgetTester tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'OTP sent'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordSheet(initialEmail: 'learner@dolphincoder.com'),
            ),
          ),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);
      await tester.tap(find.text('SEND VERIFICATION CODE'));
      await tester.pumpAndSettle();

      // Should now show Step 2
      expect(find.text('Verify & Reset'), findsOneWidget);
      expect(find.text('Code sent to learner@dolphincoder.com'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('RESET PASSWORD'), findsOneWidget);
    });
  });

  group('LoginScreen and RegisterScreen UI Tests', () {
    testWidgets('LoginScreen renders Continue with Google and Forgot Password handler', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);

      // Tapping Forgot Password opens ForgotPasswordSheet
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordSheet), findsOneWidget);
    });

    testWidgets('RegisterScreen renders Continue with Google button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
    });
  });

  group('VerifyEmailScreen Full-Page Tests', () {
    testWidgets('renders check inbox title, email badge, edit button, and 3D button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyEmailScreen(email: 'polyglot@dolphincoder.com'),
          ),
        ),
      );

      expect(find.text('Check Your Inbox'), findsOneWidget);
      expect(find.text('polyglot@dolphincoder.com'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('VERIFY & START LEARNING 🐬'), findsOneWidget);
    });

    testWidgets('entering 6-digit OTP calls verifyRegistrationOtp', (WidgetTester tester) async {
      RequestOptions? recordedOptions;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockAuthAdapter((options) async {
        recordedOptions = options;
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'token': 'verified_user_token',
            'user': {
              '_id': 'user_123',
              'name': 'Dolphin Polyglot',
              'email': 'polyglot@dolphincoder.com',
              'role': 'student',
            },
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyEmailScreen(email: 'polyglot@dolphincoder.com'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(recordedOptions, isNotNull);
      expect(recordedOptions!.path, equals(ApiConstants.verifyRegistrationOtp));
    });
  });

  group('EmailVerificationSheet Modal Tests', () {
    testWidgets('renders Verify Your Email modal sheet', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EmailVerificationSheet(email: 'sheet@dolphincoder.com'),
            ),
          ),
        ),
      );

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('sheet@dolphincoder.com'), findsOneWidget);
      expect(find.text('VERIFY & CONTINUE'), findsOneWidget);
    });
  });
}
