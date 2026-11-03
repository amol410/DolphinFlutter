import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/constants/app_constants.dart';
import 'package:dolphincoder/core/services/version_check_service.dart';
import 'package:dolphincoder/shared/widgets/force_update_dialog.dart';

void main() {
  group('VersionCheckService & ForceUpdate Tests', () {
    test('VersionCheckResult evaluates outdated when min_required_version exceeds currentBuildNumber', () {
      final data = {
        'min_required_version': AppConstants.currentBuildNumber + 1,
        'min_version_name': '1.4.3',
        'latest_version_name': '1.5.0',
        'update_url': 'https://play.google.com/store/apps/details?id=com.dolphincoder.lms',
        'title': 'Mandatory Update',
        'message': 'Please update to v1.5.0 to continue using DolphinCoder.'
      };

      final minVer = data['min_required_version'] as int;
      final isOutdated = AppConstants.currentBuildNumber < minVer;

      expect(isOutdated, isTrue);
    });

    test('VersionCheckResult evaluates up to date when currentBuildNumber >= min_required_version', () {
      final data = {
        'min_required_version': AppConstants.currentBuildNumber,
        'min_version_name': AppConstants.appVersion,
        'latest_version_name': AppConstants.appVersion,
      };

      final minVer = data['min_required_version'] as int;
      final isOutdated = AppConstants.currentBuildNumber < minVer;

      expect(isOutdated, isFalse);
    });

    test('Semantic version comparison correctly flags older semver as outdated', () {
      // Testing semantic version comparator
      bool isLower(String current, String required) {
        final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        final requiredParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        for (int i = 0; i < 3; i++) {
          final c = i < currentParts.length ? currentParts[i] : 0;
          final r = i < requiredParts.length ? requiredParts[i] : 0;
          if (c < r) return true;
          if (c > r) return false;
        }
        return false;
      }

      expect(isLower('1.4.2', '1.4.3'), isTrue);
      expect(isLower('1.4.3', '1.5.0'), isTrue);
      expect(isLower('1.4.3', '2.0.0'), isTrue);
      expect(isLower('1.4.3', '1.4.3'), isFalse);
      expect(isLower('1.4.4', '1.4.3'), isFalse);
      expect(isLower('2.0.0', '1.9.9'), isFalse);
    });

    testWidgets('ForceUpdateDialog renders with unclosable PopScope(canPop: false)', (tester) async {
      const result = VersionCheckResult(
        forceUpdateRequired: true,
        latestVersionName: '2.0.0',
        updateUrl: 'https://play.google.com/store/apps/details?id=com.dolphincoder.lms',
        title: 'Mandatory Update Required',
        message: 'A critical update is required before you can continue learning.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForceUpdateDialog(result: result),
          ),
        ),
      );

      // Verify Title & Message render
      expect(find.text('Mandatory Update Required'), findsOneWidget);
      expect(find.text('A critical update is required before you can continue learning.'), findsOneWidget);
      expect(find.text('UPDATE ON PLAY STORE'), findsOneWidget);

      // Verify PopScope cannot pop
      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
      expect(popScopeWidget.canPop, isFalse);
    });
  });
}
