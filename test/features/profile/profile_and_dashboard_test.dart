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
import 'package:dolphincoder/features/auth/data/models/user_model.dart';
import 'package:dolphincoder/features/dashboard/data/models/activity_model.dart';
import 'package:dolphincoder/features/profile/screens/change_password_screen.dart';
import 'package:dolphincoder/features/profile/screens/edit_profile_screen.dart';
import 'package:dolphincoder/shared/widgets/app_text_field.dart';

class MockProfileAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockProfileAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

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

  group('UserModel, SubjectModel & ActivityModel Tests', () {
    test('UserModel serializes, deserializes, and computes initials', () {
      const user = UserModel(
        id: 'u_1',
        name: 'Amol Shinde',
        email: 'amol@dolphincoder.com',
        role: 'student',
        bio: 'Learning German A1',
      );

      expect(user.initials, 'AS');
      final jsonStr = user.toJsonString();
      final restored = UserModel.fromJsonString(jsonStr);
      expect(restored.id, 'u_1');
      expect(restored.name, 'Amol Shinde');
      expect(restored.email, 'amol@dolphincoder.com');
      expect(restored.bio, 'Learning German A1');

      const singleName = UserModel(
        id: 'u_2',
        name: 'Dolphin',
        email: 'd@dolphincoder.com',
        role: 'student',
      );
      expect(singleName.initials, 'D');

      const multiSpaceName = UserModel(
        id: 'u_3',
        name: 'Amol   Shinde',
        email: 'amol@dolphincoder.com',
        role: 'student',
      );
      expect(multiSpaceName.initials, 'AS');
    });

    test('Validators.passwordStrength scores weak, medium, and strong passwords', () {
      expect(Validators.passwordStrength('123'), 0);
      expect(Validators.passwordStrength('abcdef'), 1); // Weak
      expect(Validators.passwordStrength('Abcdefgh'), 2); // Medium
      expect(Validators.passwordStrength('Abcdefgh1!'), 3); // Strong
    });

    test('TodayCounts & ActivityItem parse backend JSON accurately', () {
      final counts = TodayCounts.fromJson({
        'quizCount': 2,
        'noteCount': 3,
        'flashcardCount': 1,
        'karaokeCount': 1,
        'total': 7,
      });
      expect(counts.quizCount, 2);
      expect(counts.noteCount, 3);
      expect(counts.total, 7);

      final act = ActivityItem.fromJson({
        'id': 101,
        'activityType': 'quiz',
        'resourceId': 42,
        'resourceTitle': 'Verb Quiz',
        'activityDate': '2026-10-30',
        'createdAt': '2026-10-30T10:00:00Z',
        'metadata': {'score': 9, 'maxScore': 10, 'percentage': 90, 'passed': true, 'timeTakenSecs': 60},
      });
      expect(act.id, 101);
      expect(act.activityType, 'quiz');
      expect(act.resourceTitle, 'Verb Quiz');
      expect(act.score, 9);
      expect(act.percentage, 90.0);
      expect(act.passed, isTrue);
      expect(act.secondsSpent, 60);
    });
  });

  group('ChangePasswordScreen & EditProfileScreen Widget Tests', () {
    testWidgets('ChangePasswordScreen validates password length and matching confirmation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChangePasswordScreen(),
          ),
        ),
      );

      expect(find.text('Change Password'), findsOneWidget);

      // Tap Update Password with empty fields
      final updateBtn = find.text('Update Password');
      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Password is required'), findsWidgets);

      // Enter mismatched passwords
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'OldPass123');
      await tester.enterText(fields.at(1), 'NewPass123!');
      await tester.enterText(fields.at(2), 'DifferentPass!');
      await tester.pump();

      await tester.ensureVisible(updateBtn);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('EditProfileScreen renders and updates user profile via PUT /auth/profile', (tester) async {
      bool profileUpdated = false;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockProfileAdapter((options) async {
        if (options.path.contains(ApiConstants.updateProfile)) {
          profileUpdated = true;
          return ResponseBody.fromString(
            jsonEncode({
              'user': {
                '_id': 'u_1',
                'name': 'Updated Learner',
                'email': 'learner@dolphincoder.com',
                'role': 'student',
                'bio': 'Fluent in German',
              }
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );

      expect(find.text('Edit Profile'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Updated Learner');
      await tester.enterText(fields.at(1), 'Fluent in German');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profileUpdated, isTrue);
    });
  });
}
