import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class VersionCheckResult {
  final bool forceUpdateRequired;
  final String latestVersionName;
  final String updateUrl;
  final String title;
  final String message;

  const VersionCheckResult({
    required this.forceUpdateRequired,
    required this.latestVersionName,
    required this.updateUrl,
    required this.title,
    required this.message,
  });

  static const defaultClean = VersionCheckResult(
    forceUpdateRequired: false,
    latestVersionName: AppConstants.appVersion,
    updateUrl: AppConstants.playStoreUrl,
    title: 'Update Required',
    message: 'A newer version of DolphinCoder is available on Google Play. Please update to continue your learning journey.',
  );
}

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'Accept': 'application/json'},
    ),
  );

  /// Checks if an update is mandatory.
  /// If network fails, times out, or URL is 404, fails open (returns false)
  /// so offline or poor connectivity does not erroneously crash or block users.
  Future<VersionCheckResult> checkVersion() async {
    try {
      final response = await _dio.get(AppConstants.versionCheckUrl);
      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data;
        Map<String, dynamic>? data;

        if (raw is Map) {
          data = Map<String, dynamic>.from(raw);
        } else if (raw is String) {
          data = Map<String, dynamic>.from(json.decode(raw) as Map);
        }

        if (data != null) {
          final minRequiredVersion = data['min_required_version'] is int
              ? data['min_required_version'] as int
              : int.tryParse(data['min_required_version']?.toString() ?? '0') ?? 0;

          final latestVersionName = (data['latest_version_name'] ?? AppConstants.appVersion).toString();
          final updateUrl = (data['update_url'] ?? AppConstants.playStoreUrl).toString();
          final title = (data['title'] ?? 'Update Required').toString();
          final message = (data['message'] ?? 'A newer version of DolphinCoder is available on Google Play. Please update to continue.').toString();

          // Force update if installed build number is strictly lower than min_required_version
          final isOutdated = AppConstants.currentBuildNumber < minRequiredVersion;

          return VersionCheckResult(
            forceUpdateRequired: isOutdated,
            latestVersionName: latestVersionName,
            updateUrl: updateUrl,
            title: title,
            message: message,
          );
        }
      }
    } catch (e) {
      debugPrint('[VersionCheckService] Check failed or skipped: $e');
    }

    return VersionCheckResult.defaultClean;
  }
}
