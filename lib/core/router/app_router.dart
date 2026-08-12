import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/notes/screens/notes_screen.dart';
import '../../features/notes/screens/note_detail_screen.dart';
import '../../features/videos/screens/videos_screen.dart';
import '../../features/videos/screens/video_detail_screen.dart';
import '../../features/quizzes/screens/quizzes_screen.dart';
import '../../features/quizzes/screens/quiz_detail_screen.dart';
import '../../features/quizzes/screens/quiz_take_screen.dart';
import '../../features/quizzes/screens/quiz_result_screen.dart';
import '../../features/flashcards/screens/flashcards_screen.dart';
import '../../features/flashcards/screens/study_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../constants/app_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      final isAuth = token != null;
      final loc = state.matchedLocation;

      final publicRoutes = ['/', '/onboarding', '/login', '/register'];
      if (!isAuth && !publicRoutes.contains(loc)) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Shell (bottom nav)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/notes',
            builder: (_, __) => const NotesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    NoteDetailScreen(noteId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/quizzes',
            builder: (_, __) => const QuizzesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    QuizDetailScreen(quizId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'take',
                    builder: (_, state) =>
                        QuizTakeScreen(quizId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'result',
                    builder: (_, state) => QuizResultScreen(
                      quizId: state.pathParameters['id']!,
                      result: state.extra as Map<String, dynamic>? ?? {},
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/flashcards',
            builder: (_, __) => const FlashcardsScreen(),
            routes: [
              GoRoute(
                path: ':id/study',
                builder: (_, state) =>
                    StudyScreen(deckId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
              GoRoute(path: 'password', builder: (_, __) => const ChangePasswordScreen()),
            ],
          ),
        ],
      ),

      // Floating routes (no bottom nav)
      GoRoute(path: '/videos', builder: (_, __) => const VideosScreen()),
      GoRoute(
        path: '/videos/:id',
        builder: (_, state) =>
            VideoDetailScreen(videoId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
