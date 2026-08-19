# DolphinCoder Flutter App — Context & Progress Log

> **Purpose:** Token-safe checkpoint. If conversation resets, read this file to resume exactly where we left off.
> **GitHub Repo:** https://github.com/amol410/DolphinFlutter.git
> **App Location:** `/Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/app/dolphincoder/`
> **IMPORTANT:** Do NOT touch `backend/` or `frontend/` — they are in production (deployed).

---

## 🗂 Source Documents

| File | Purpose |
|------|---------|
| `app/plan.md` | Full architecture plan (tech stack, design system, 20 screens) |
| `app/prompts.md` | Screen-by-screen AI prompts with full design specs |
| `app/dolphincoder/context.md` | **This file** — live progress log & bug fix history |

---

## ✅ VERSION HISTORY

### v1.0.0 — Full App (COMPLETE ✅)
**Status:** All 20 screens built, tested on physical Android device via APK. Backend is live in production. App connects to production API.

### v0.4.0 — Flashcards + Profile ✅
### v0.3.0 — Videos + Quizzes ✅
### v0.2.0 — Dashboard + Notes ✅
### v0.1.0 — Foundation ✅

---

## 📁 Complete File List (All Done)

### Root
- [x] `pubspec.yaml` — All dependencies: riverpod, go_router, dio, flutter_secure_storage, shared_preferences, google_fonts, flutter_animate, cached_network_image, shimmer, flutter_html, webview_flutter, percent_indicator, image_picker, url_launcher, intl, timeago, etc.
- [x] `lib/main.dart` — ProviderScope + DolphinCoderApp
- [x] `lib/app.dart` — MaterialApp.router with AppTheme.dark

### Core Layer (`lib/core/`)
- [x] `constants/app_constants.dart` — appName, tokenKey, userDataKey, apiBaseUrlKey
- [x] `constants/api_constants.dart` — All API endpoints, defaultBaseUrl = `http://10.0.2.2:5000/api` (Android emulator), productionBaseUrl, getBaseUrl() reads from SharedPreferences
- [x] `theme/app_colors.dart` — Full color palette (#0A0F1E background, #6366F1 primary, #A855F7 accent, note colors, deck gradient colors)
- [x] `theme/app_theme.dart` — Complete dark ThemeData with Google Fonts (Plus Jakarta Sans + Inter)
- [x] `network/api_exception.dart` — Custom ApiException class
- [x] `network/dio_client.dart` — Dio singleton with Bearer token interceptor, 401 auto-logout, reset()
- [x] `utils/validators.dart` — email, password, required, minLength, passwordStrength (returns 1/2/3)
- [x] `router/app_router.dart` — Complete go_router with ShellRoute (bottom nav), redirect guard (reads JWT), all 20 routes

### Shared Widgets (`lib/shared/widgets/`)
- [x] `glass_card.dart` — GlassCard widget (bg #111827, border white/0.08, BoxShadow with primary tint, InkWell tap)
- [x] `gradient_button.dart` — GradientButton (indigo→violet gradient, scale press animation, loading spinner, disabled state)
- [x] `app_text_field.dart` — AppTextField (label above, dark fill, indigo focus, error border)
- [x] `bottom_nav.dart` — AppShell with BottomNavigationBar (5 tabs: Home/Notes/Quizzes/Flashcards/Profile)
- [x] `subject_badge.dart` — SubjectBadge (purple pill) + TopicBadge (blue pill)
- [x] `shimmer_loader.dart` — ShimmerBox, ShimmerCard, ShimmerGridLoader, ShimmerListLoader
- [x] `empty_state.dart` — EmptyState (emoji + title + subtitle + optional CTA button)

### Auth Feature (`lib/features/auth/`)
- [x] `data/models/user_model.dart` — UserModel (id, name, email, role, avatar, bio), initials getter, copyWith
- [x] `data/auth_repository.dart` — login(), register(), getMe(), updateProfile(), changePassword(), logout(), getToken(), getCachedUser(), _saveSession()
- [x] `providers/auth_provider.dart` — AuthState class, AuthNotifier (StateNotifier), authProvider
- [x] `screens/splash_screen.dart` — Pulsing glow animation, JWT check to /home or /onboarding
- [x] `screens/onboarding_screen.dart` — 3 slides, animated dot indicators, Skip/Next/"Get Started"
- [x] `screens/login_screen.dart` — Email+password form, validation, Riverpod login, error snackbar
- [x] `screens/register_screen.dart` — Name+email+password, live password strength bar (3 segments), Riverpod register

### Data Models
- [x] `features/notes/data/models/note_model.dart`
- [x] `features/videos/data/models/video_model.dart`
- [x] `features/quizzes/data/models/quiz_model.dart` — QuizModel + QuizQuestion + AttemptModel + AttemptAnswer
- [x] `features/flashcards/data/models/flashcard_model.dart` — FlashcardDeck + Flashcard

### Repositories (Data Layer)
- [x] `features/notes/data/notes_repository.dart`
- [x] `features/videos/data/videos_repository.dart`
- [x] `features/quizzes/data/quiz_repository.dart` — getQuizzes, getQuizById, submitAttempt, getMyAttempts
- [x] `features/flashcards/data/flashcard_repository.dart`

### Providers (State Layer)
- [x] `features/notes/providers/notes_provider.dart`
- [x] `features/videos/providers/videos_provider.dart`
- [x] `features/quizzes/providers/quiz_provider.dart` — QuizzesListNotifier + quizDetailProvider + myAttemptsProvider + QuizTakeNotifier (autoDispose) + quizResultProvider (StateProvider.family — persists result across navigation)
- [x] `features/flashcards/providers/flashcard_provider.dart`

### All Screens (Steps 3–8)
- [x] `features/dashboard/screens/dashboard_screen.dart`
- [x] `features/notes/screens/notes_screen.dart`
- [x] `features/notes/screens/note_detail_screen.dart`
- [x] `features/videos/screens/videos_screen.dart`
- [x] `features/videos/screens/video_detail_screen.dart`
- [x] `features/quizzes/screens/quizzes_screen.dart`
- [x] `features/quizzes/screens/quiz_detail_screen.dart`
- [x] `features/quizzes/screens/quiz_take_screen.dart` — Bug fixed (see BUG-001)
- [x] `features/quizzes/screens/quiz_result_screen.dart` — Enhanced (see ENHANCEMENT-001)
- [x] `features/flashcards/screens/flashcards_screen.dart`
- [x] `features/flashcards/screens/study_screen.dart`
- [x] `features/profile/screens/profile_screen.dart`
- [x] `features/profile/screens/edit_profile_screen.dart`
- [x] `features/profile/screens/change_password_screen.dart`
- [x] `features/profile/screens/settings_screen.dart`

### Android Config
- [x] `android/app/src/main/AndroidManifest.xml` — INTERNET + CAMERA + READ/WRITE_EXTERNAL_STORAGE permissions
- [x] `android/app/build.gradle.kts` — minSdk = 23

---

## 🐛 BUG FIX LOG

> This section documents every bug found in production/testing and how it was resolved.
> Future AI sessions: read this BEFORE touching quiz-related code.

---

### BUG-001 — Quiz Submit: Dialog Stuck + Navigates to Detail Screen Instead of Result
**Date:** 2026-08-19
**Severity:** Critical — app completely broken after quiz submission
**Files Changed:** `quiz_take_screen.dart`

#### Symptoms
1. After tapping Submit on the quiz take screen, the "Submit Quiz?" confirmation dialog appeared.
2. After tapping Submit or Cancel in the dialog, the app navigated BACK to the Quiz Detail screen instead of the Result screen.
3. The "Submit Quiz?" dialog remained visible on top of the Quiz Detail screen — app was stuck.
4. The Start Quiz button was visible behind the floating dialog.

#### Root Cause Analysis (3 bugs compounding each other)

**Bug A — Wrong Navigator.pop context (PRIMARY cause)**

Inside a ShellRoute, go_router creates its own nested Navigator. When you call `Navigator.pop(context)` using the SCREEN's context (not the dialog's context), Flutter pops the ROUTE from the ShellRoute's navigator instead of dismissing the dialog overlay. The Quiz Take screen disappears, the app lands on Quiz Detail, and the dialog floats orphaned on top.

```dart
// WRONG — pops the screen route, not the dialog
builder: (_) => AlertDialog(
  actions: [
    TextButton(onPressed: () => Navigator.pop(context, false), ...),
    TextButton(onPressed: () => Navigator.pop(context, true), ...),
  ],
)

// FIXED — use dialogContext scoped to the overlay entry
builder: (dialogContext) => AlertDialog(
  actions: [
    TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), ...),
    TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), ...),
  ],
)
```

**Bug B — context.go() drops extra data inside ShellRoute**

`context.go()` triggers a full route stack rebuild in go_router. When called from within a ShellRoute child, the `extra` Map is dropped during route matching. QuizResultScreen receives `result: {}` (empty map), hits the error state, and shows nothing.

```dart
// WRONG — extra gets dropped inside ShellRoute rebuild
context.go('/quizzes/${widget.quizId}/result', extra: resultData);

// FIXED — pushReplacement preserves the extra + store in provider as fallback
ref.read(quizResultProvider(widget.quizId).notifier).state = resultData;
context.pushReplacement('/quizzes/${widget.quizId}/result', extra: resultData);
```

**Bug C — Timer race condition / double-submit**

The countdown timer was not cancelled before the API call. If the timer fired during the HTTP request, `_submit()` could be called a second time.

```dart
// FIXED — guard + cancel timer before API call
if (ref.read(quizTakeProvider).isSubmitting) return;
...
_timer?.cancel();
_timer = null;
```

#### Fix Summary Table

| Change | File |
|--------|------|
| `builder: (_)` changed to `builder: (dialogContext)` | quiz_take_screen.dart |
| `Navigator.pop(context, x)` changed to `Navigator.of(dialogContext).pop(x)` | quiz_take_screen.dart |
| `context.go(...)` changed to `context.pushReplacement(...)` | quiz_take_screen.dart |
| Store result in `quizResultProvider` before navigating | quiz_take_screen.dart |
| Added `isSubmitting` guard at top of `_submit()` | quiz_take_screen.dart |
| Cancel timer before API call | quiz_take_screen.dart |
| Added `barrierDismissible: false` on dialog | quiz_take_screen.dart |

---

### ENHANCEMENT-001 — Quiz Result Screen: Always-Visible Explanations + Bigger Fonts
**Date:** 2026-08-19
**File Changed:** `quiz_result_screen.dart`

#### What Changed
- Removed `ExpansionTile` accordion — explanations now always shown inline, no tap needed.
- Question text font: 13px to 15px. Answer text: 12px to 14px. Explanation: 12px to 14px.
- Removed `maxLines: 3` clamp — full question text always visible.
- Skipped questions now show correct answer AND explanation (previously only showed "Skipped").
- Added new `_AnswerRow` widget for "Your answer" / "Correct answer" rows with icons.
- Added Correct/Wrong/Skipped status badge in top-right corner of each card.
- Explanation shown in a styled dark inner box with lightbulb icon.

#### Before vs After

| | Before | After |
|--|--------|-------|
| Question text | 3 lines max, 13px | Full text, 15px bold |
| Your answer | 12px plain text | 14px with check/cross icon |
| Correct answer | Hidden for skipped | Always shown for wrong/skipped |
| Explanation | Tap to expand accordion | Always visible, 14px, styled box |
| Status indicator | Left border color only | Border + Correct/Wrong/Skipped badge |

---

## 🔧 How to Resume (Next Session)

1. Read this file first
2. Check **Bug Fix Log** — avoid re-introducing fixed bugs
3. App is fully built — focus on new features or further polish

---

## 📱 Build & Run Reference

### Build APK (for physical device testing)
```bash
cd /Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/app/dolphincoder
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Install via ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Get logs from physical device (connect via USB)
```bash
adb logcat -s flutter
# or
adb logcat | grep -i flutter
```

### Run on emulator
```bash
flutter run
# r = hot reload | R = hot restart | q = quit
```

### Change API URL at Runtime
Go to Profile > Settings > API Base URL > enter production URL > restart app.

---

## 🎨 Design System Quick Reference

| Token | Value |
|-------|-------|
| Background | #0A0F1E |
| Surface | #111827 |
| Surface2 | #1A2235 |
| Border | #FFFFFF12 |
| Primary (Indigo) | #6366F1 |
| Accent (Violet) | #A855F7 |
| Success | #10B981 |
| Error | #EF4444 |
| Warning | #F59E0B |
| Text Primary | #F9FAFB |
| Text Secondary | #9CA3AF |
| Text Muted | #4B5563 |
| Heading Font | Plus Jakarta Sans |
| Body Font | Inter |

---

## 🔗 Key API Endpoints (Backend — Production)

> Backend is deployed. Do NOT modify backend or frontend code without asking the user first.

```
POST /api/auth/login           { email, password } -> { token, user }
POST /api/auth/register        { name, email, password } -> { token, user }
GET  /api/auth/me              (Bearer) -> { user }
GET  /api/subjects             -> [{ id, name, topics }]
GET  /api/notes                ?q=&subject=&topic=&page=&limit=
GET  /api/notes/:id            -> note detail
GET  /api/videos               ?q=&page=&limit=
GET  /api/videos/:id           -> video detail
GET  /api/quizzes              ?q=&subject=&topic=&page=&limit=
GET  /api/quizzes/:id          -> quiz with questions (no correct answers exposed)
POST /api/quizzes/:id/attempt  { answers: [{questionId, chosenIndex}], timeTakenSecs }
                               -> { success, result: { attempt, questions } }
GET  /api/quizzes/:id/attempts -> my attempts history
GET  /api/flashcards           -> decks list
GET  /api/flashcards/:id       -> deck + cards
GET  /api/flashcards/:id/progress
POST /api/flashcards/:id/progress  { cardResults, masteredCount }
PUT  /api/auth/profile         { name, bio }
PUT  /api/auth/password        { currentPassword, newPassword }
```

### Quiz Submit — Backend Response Shape
```json
{
  "success": true,
  "result": {
    "attempt": {
      "_id": "...", "score": 8, "maxScore": 10,
      "percentage": 80, "passed": true, "timeTakenSecs": 240
    },
    "questions": [
      {
        "_id": 0, "text": "What is...", "options": ["A","B","C","D"],
        "correctIndex": 2, "explanation": "Because...",
        "chosenIndex": 2, "isCorrect": true
      }
    ]
  }
}
```

> NOTE: quiz_repository.dart maps result.questions into AttemptAnswer objects.
> It translates chosenIndex -> selectedIndex and isCorrect -> correct.
> Do NOT change this mapping.

---

## KNOWN GOTCHAS (Read Before Touching Quiz Code)

1. ShellRoute + Navigator.pop(context): Never use the screen's BuildContext inside a
   dialog opened from a ShellRoute child. Always use dialogContext (the builder param)
   for Navigator.of(dialogContext).pop(). Using screen context pops the ROUTE not the dialog.

2. ShellRoute + context.go() with extra: context.go() drops the extra object when
   navigating between sibling routes inside a ShellRoute. Use context.pushReplacement()
   instead. Always store critical data in a Riverpod provider before navigating as fallback.

3. quizTakeProvider is autoDispose: It clears when Quiz Take screen is destroyed.
   quizResultProvider (non-autoDispose, StateProvider.family) is the reliable data source
   for the Result screen. It is set in _submit() BEFORE navigation.

4. Answer field name mapping: Backend sends chosenIndex (not selectedIndex) and
   isCorrect (not correct). quiz_repository.dart remaps these. Do not change this mapping.

---

*Last updated: 2026-08-19 | Conversation ID: 7f77e111-4e3d-4bc7-a3bf-30e612789492*
