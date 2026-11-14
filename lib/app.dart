import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/network/dio_client.dart';
import 'core/services/ad_service.dart';
import 'core/services/version_check_service.dart';
import 'features/gamification/providers/gamification_provider.dart';
import 'shared/widgets/force_update_dialog.dart';

class DolphinCoderApp extends ConsumerStatefulWidget {
  const DolphinCoderApp({super.key});

  @override
  ConsumerState<DolphinCoderApp> createState() => _DolphinCoderAppState();
}

class _DolphinCoderAppState extends ConsumerState<DolphinCoderApp> with WidgetsBindingObserver {
  bool _isCheckingVersion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForceUpdateOnResume();
      _syncCurriculumOnResume();
      AdService().warmUp();
    }
  }

  void _syncCurriculumOnResume() {
    try {
      final token = DioClient.cachedToken;
      if (token == null || token.isEmpty) return;

      // Never call loadPath() with no language: that path used to fall back to
      // German and silently replace the learner's active course with 'de'.
      // Only the last known, non-null course may be re-synced; when none is
      // known yet the status provider is already fetching it.
      final status = ref.read(gamificationStatusProvider).asData?.value;
      if (status == null) return;

      ref.read(pathNodesProvider.notifier).loadPath(
            targetLanguage: status.targetLanguage,
            nativeLanguage: status.nativeLanguage,
            level: status.currentLevel,
            silent: true,
          );
    } catch (_) {}
  }

  Future<void> _checkForceUpdateOnResume() async {
    if (_isCheckingVersion) return;
    _isCheckingVersion = true;
    try {
      final result = await VersionCheckService().checkVersion();
      if (result.forceUpdateRequired && mounted) {
        final navContext = rootNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          await ForceUpdateDialog.show(navContext, result);
        }
      }
    } catch (_) {
    } finally {
      _isCheckingVersion = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    AppColors.isDark = themeMode == ThemeMode.dark;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
