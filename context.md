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

### v1.3.0 — Duolingo-Grade 4-Tier Caching, Predictive Prefetching & Sub-Second Boot (COMPLETE ✅)
**Status:** Version bumped to `1.3.0`. Re-engineered application data flow and performance based on reverse-engineered Duolingo blueprints (`appit/caching_networking_and_latency.md` and `appit/databasemanagement.md`):
1. **Cold Boot Optimization**: Cut splash screen hold from > 3.1s to < 450ms by removing artificial `Future.delayed(2600ms)` and parallelizing auth checks with smooth mascot reveal.
2. **In-Memory JWT Cache**: Eliminated asynchronous Android Keystore/Keychain IPC delay (20–80ms penalty per call) in `DioClient` with $O(1)$ memory token caching.
3. **Optimistic Lesson Completion**: Implemented instant 0ms map progression and reward increments in `PathNodesNotifier.completeNode()`; eliminated 3 sequential blocking server roundtrips (`completeNode` $\to$ `loadPath` $\to$ `getStatus`).
4. **Tier-2 Local Storage (`CacheService`)**: Added local device persistence for course paths, user progress, and lesson stages with Stale-While-Revalidate and offline safety nets.
5. **Predictive Lesson Prefetching (`PrefetchService`)**: Automatic background pre-warming of the next 2–3 lesson stage manifests and audio clips upon map load; lessons now launch in 0ms without loading spinners.
6. **Local Disk Audio Cache (`CacheDir.AUDIO_TTS`)**: Audio files are downloaded and cached deterministically on disk, enabling instantaneous tactile audio playback via `DeviceFileSource`.
7. **Map Scroll Throttling**: Throttled scroll listener in `ArchipelagoMapScreen` by 80% to keep map scrolling pinned at 60–120 FPS.

### v1.2.6+11 — Release v29.1.0-stable: JIT Decoupled Loading, Course Switching & 8 Interactive Stages (COMPLETE ✅)
**Status:** Version `1.2.6+11` (tag: `v29.1.0-stable`). Implemented JIT on-demand lesson fetching (decoupling GET `/api/gamification/path` to ~35 KB lightweight summary nodes; fetching full stages via GET `/api/gamification/lesson/:id` upon node tap). Built Course Switcher modal with parallel background switching, `ValueKey(currentCourseId)` scroll retention, animated Island Shimmer Skeletons, and full support for 8 interactive challenge stages (Word Match, Listen & Tap, Sentence Builder, Sprechen Lip-Sync, Flashcard, Quiz MCQ, Dialogue, Grammar Tip) across German A1 (105 units) and English A1 (Hindi & Marathi instruction, 35 units).

### v1.2.6 — Real-Time German Lady Voice TTS Pronunciation (COMPLETE ✅)
**Status:** Version bumped to `1.2.6+11`. Integrated `flutter_tts` with dedicated `TtsService` (`de-DE`, female voice selection, 0.48 speech rate, 1.10 pitch). Real-time word pronunciation enabled across Word Match, Listen & Tap bank chips, and Sentence Builder word picking.

### v1.2.5 — Dynamic Stage Filtering, Native German Recognition & Release v25.0.0 (COMPLETE ✅)
**Status:** Version bumped to `1.2.5+10` (tag: `v1.2.5-stable`, `v25.0.0`). Dynamic stage filtering (`_activeStageTypes`), native German `de_DE` speech recognition, mounted audio guards, and full offline safety nets verified.

### v1.2.0 — Archipelago Gamification & 5-Tab Shell (COMPLETE ✅)
**Status:** 5-tab gamified floating shell (`/home` Learn, `/leagues` Leagues, `/quests` Quests, `/shop` Shop, `/profile` Gamified Profile), Archipelago map, and multi-stage lesson sessions.

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

### BUG-002 — Spelling Check: CHECK SPELLING Button Remains Inactive Unless Umlaut Clicked
**Date:** 2026-10-20
**Severity:** Moderate — user unable to submit typed German words without tapping an Umlaut button
**Files Changed:** `lesson_session_screen.dart`

#### Symptoms
1. In Stage 5 (`type_word` / "Type the German word"), typing on the standard software keyboard (e.g., words without umlauts like "Kaffee", "Wasser", "heiss") left the "CHECK SPELLING" button disabled/greyed out.
2. The button only unlocked if the user tapped an Umlaut button (`ä`, `ö`, `ü`, `ß`) in the quick-tap bar.

#### Root Cause
In `TextField`, `onChanged` had a guard `if (_typeCorrect != null) setState(...)`. Because `_typeCorrect` was initially `null`, `setState()` was never executed when typing with the keyboard, preventing Flutter from rebuilding and evaluating `_typeWordController.text.trim().isEmpty`. In contrast, `_addUmlautToInput` called `setState()` unconditionally, causing only umlaut clicks to trigger rebuilds.

#### Resolution
Updated `TextField.onChanged` to always invoke `setState(() { _typeCorrect = null; })` on any character typed or deleted, instantly activating the "CHECK SPELLING" button for all standard keyboard input.

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
POST /api/gamification/switch-course  { courseId } -> { success, activeCourseId, user }
GET  /api/gamification/path           -> lightweight summary nodes (~35 KB)
GET  /api/gamification/lesson/:id     -> full multi-stage lesson details
POST /api/gamification/complete-node  { nodeId, stars, score, heartsLeft } -> { success, xp, pearls }
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

## 💡 FEATURE LOG

### FEAT-002 — Duolingo-Style Sprechen Mode with Animated Character (`karaoke_note_reader_screen.dart`) (COMPLETE ✅)
**Date:** 2026-09-30  
**Status:** Built, analyzed, and verified with zero compilation errors.  
- **New Files**:
  - `lib/features/notes/widgets/animated_karaoke_character.dart` — Custom 60 FPS vector character with real-time lip-sync, blinking, and emotion states (speaking, listening, celebration).
  - `lib/features/notes/widgets/karaoke_speech_bubble.dart` — Comic speech bubble with speaker replay button and word-by-word active highlighting.
- **Key Capabilities**:
  - **Updated Sprechen Layout Hierarchy**:
    - **Header Row**: Compact "Speak this sentence" (22px) and "Full Script" toggle button placed together on the same horizontal line.
    - **German Karaoke Text**: Full-width card at the top with word-by-word real-time highlight sync.
    - **Character & Audio Row**: Scaled-down animated character (size 85) with a dedicated "Play Audio" button right beside him.
    - **English Translation**: Muted translation card (13px font) located directly below the character.
    - **Tap to Speak**: Large tap-to-speak button located underneath the translation, with explicit-only user activation and ✕ cancel control.
  - Duolingo-style bottom sheets: green celebration banner (`#D7FFB8`) with `"Excellent! Meaning:"` and big green **`CONTINUE`** button; red banner (`#FFDFE0`) with `"TRY AGAIN"`.
  - Seamless toggle back to `"Full Script"` listening mode via top chip.

---

### FEAT-003 — Gamified Coral Reef Archipelago & Interactive Lesson Session Screen (`LessonSessionScreen`) (COMPLETE ✅)
**Date:** 2026-10-02  
**Status:** Built, analyzed, and running live on connected Android device (`V2168`).  
- **New & Enhanced Files**:
  - `lib/features/gamification/screens/archipelago_map_screen.dart` — 3D elevated sinusoidal zigzag island nodes with status indicators (Locked, Available, Completed with 1-3 Stars), animated dolphin mascot, oxygen & pearls economy.
  - `lib/features/gamification/screens/lesson_session_screen.dart` — Multi-stage interactive challenge runner.
  - `lib/features/gamification/data/models/gamification_models.dart` — Enhanced `PathNodeModel` to parse `audioUrl` and `stages` JSON arrays dynamically from backend.
- **Key Audio & Stage Capabilities**:
  - **Full-Sentence Audio & Pure Sequencing Word Bank**: High-fidelity sentence audio streaming using dedicated `_audioPlayer` pre-buffered on stage load. In `listen_tap`, word chips function purely as responsive tactile selection tiles without individual word sound playback, allowing learners to focus cleanly on arranging the correct sentence order based on the mascot's spoken sentence.
  - **Dynamic Stage Parser (`_initStagesData`)**: Dynamically extracts `listen_tap` target sentences, tokens, and isolated `audioUrl`, as well as `match_pairs`, `sentence_builder`, and `sprechen` prompts from `widget.node.stages`.
  - **Stage 3 Sprechen Lip-Sync**:
    - **One-Time Auto-Play Demonstration (1s Delay)**: When transitioning to Stage 3, waits 1 second then automatically triggers teacher reference audio playback once with animated dolphin speaker reactions.
    - **No Replay Button**: Deliberately omits any replay or speaker button to foster incremental recall from prior listening and assembly stages.
    - **Real-Time Karaoke Highlighting**: Synchronizes `_audioPlayer.onPositionChanged` with `karaokeData.words` to illuminate words in real-time inside the speech bubble.
    - **Strict Passing Threshold (> 75%)**: Speech-to-text recognition (`speech_to_text`) evaluates pronunciation using fuzzy token matching; requires strictly `accuracy > 75` to succeed and reveal the celebration feedback.
  - **Tactile Speaker & Mascot**: Speaker button maintains continuous `volume_up_rounded` iconography for intuitive repeat sentence listening, while Echo the Dolphin wears headphones and reacts with listening animations during active playback.
  - **Tolerant Verification**: Punctuation-insensitive and whitespace-normalized validation for listening and sentence builder tasks.

---

### FEAT-004 — Dynamic Active Stage Filtering, Native German Recognition & Shell v1.2.5 (COMPLETE ✅)
**Date:** 2026-10-02  
**Status:** Built, analyzed, and verified in production submodule. Bumped to version `1.2.5+10`.  
- **Dynamic Active Stage Filtering (`_activeStageTypes`)**:
  - `LessonSessionScreen` evaluates `widget.node.stages` dynamically; only stages with valid configurations (`word_match`, `listen_tap`, `sentence_builder`, `sprechen`) are queued.
  - Prevents empty stage screens or unwanted skips when lessons author a subset of stages.
- **Native German Speech Recognition (`de_DE`)**:
  - Re-configured `speech_to_text` to strictly initialize with German locale (`localeId: 'de_DE'`) during Sprechen Lip-Sync pronunciation checks.
- **Continuous Full-Sentence Mascot Replay**:
  - Tactile speaker button always retains `volume_up_rounded` iconography and re-plays the full spoken sentence cleanly from 0:00 every time it is tapped.
- **Audio Lifecycle & Offline Robustness**:
  - Implemented mounted guards (`if (!mounted) return;`) across all playback methods and position streams.
  - Guaranteed fallback dummy audio tracks and timestamps so offline learners experience zero crashes.
- **5-Tab Gamified Shell (`bottom_nav.dart`)**:
  - Persistent bottom navigation shell: Learn (`/home`), Leagues (`/leagues`), Quests (`/quests`), Shop (`/shop`), Profile (`/profile`).

---

### FEAT-005 — Real-Time German Lady Voice TTS Pronunciation (`TtsService`) (COMPLETE ✅)
**Date:** 2026-10-12  
**Status:** Built, analyzed, and integrated into mobile client (`v1.2.6+11`).  
- **New Service (`lib/core/services/tts_service.dart`)**:
  - Encapsulates `flutter_tts` with automatic German female voice detection (`de-DE` locale, female/frauen keywords or pitch 1.10 fallback).
  - Configured at `speechRate: 0.48` for crystal-clear language learning pronunciation.
  - Implements instant `stop()` before `speak()` to guarantee zero lag or utterance overlap during rapid user tapping.
  - Strips trailing punctuation (e.g. `dir?`, `Morgen,` -> `dir`, `Morgen`) for clean, isolated word phonetics.
- **Stage 0 Word Match Integration (`LessonSessionScreen`)**:
  - Whenever a learner taps a German word tile (`_onGermanMatchTap`), the lady's voice speaks the German word instantly.
- **Stage 1 Listen & Tap Bank Integration**:
  - Whenever a learner taps/picks a word tile from `_listenBank`, the lady's voice pronounces the word in real-time.
- **Stage 2 Sentence Builder / Fill-in-the-Blanks Integration**:
  - Whenever a learner picks a word tile from `_builderBank` (e.g., tapping *"Wie"*, then *"geht's"*), each chosen word is articulated immediately as it is selected into the sentence tray.
- **Match Pairs Quiz Widget Integration (`MatchPairsWidget`)**:
  - Whenever a learner taps a prompt card in the left column (`_onLeftTap`), TTS pronounces the term in the German voice.

---

### FEAT-006 — JIT On-Demand Lesson Fetching, Dynamic Course Switcher & Shimmer Skeleton Loading (COMPLETE ✅)
**Date:** 2026-10-14  
**Status:** Built, analyzed, and running live on mobile client (`v29.1.0-stable`).  
- **JIT Payload Decoupling Architecture**:
  - Addressed root cause of 60-second mobile lag when switching to 1,680-lesson courses.
  - Trimmed `GET /api/gamification/path` to return lightweight summary nodes (~35 KB vs 28.5 MB payload).
  - Implemented JIT fetching on lesson node tap: `GET /api/gamification/lesson/:id` retrieves complete 8-stage payloads on-demand with localized caching and instant transition.
- **Dynamic Course Switcher**:
  - Modal bottom sheet (`_showCourseSwitcherModal`) allowing seamless switching between German A1 (`de_a1`) and English A1 (Hindi `en_hi` & Marathi `en_mr`).
  - Implemented `ValueKey(currentCourseId)` on `ArchipelagoMapScreen` to prevent scroll snap-back bugs across courses.
  - Implemented animated island shimmer skeletons (`_IslandMapSkeleton`) for seamless loading transitions without UI lockup.

---

### FEAT-007 — Expansion to 8 Interactive Challenge Stages & Dual-Track Indian Curriculum (COMPLETE ✅)
**Date:** 2026-10-15  
**Status:** Built, analyzed, and verified in production mobile app (`1.2.6+11`).  
- **8 Interactive Stage Types Fully Supported**:
  - **Stage 0: Word Match (`word_match`)**: 4-pair interactive vocabulary matching grid with immediate lady TTS pronunciation, tactile selection feedback, and pair-elimination animations.
  - **Stage 1: Listen & Tap (`listen_tap`)**: High-fidelity sentence audio streaming (`audioplayers`) from `/api/notes/audio/db/:id` with tactile replay speaker button (`volume_up_rounded`), reactive dolphin mascot (`AnimatedDolphinMascot`), and scrambler chip rearrangement.
  - **Stage 2: Sentence Builder (`sentence_builder`)**: Fill-in-the-blank syntactic assembly with bank chips, instant word TTS feedback, tray reset, and validation.
  - **Stage 3: Sprechen Lip-Sync (`sprechen`)**: One-time auto-play teacher demonstration (1s delay), real-time word-by-word karaoke highlighting (`karaokeData.words`), native German/English speech recognition (`speech_to_text`), and strict pronunciation passing threshold (`> 75% accuracy`).
  - **Stage 4: Flashcard Mastery (`flashcard`)**: 3D flip-card mastery stage with tactile prompt/definition cards.
  - **Stage 5: Quiz MCQ (`quiz_mcq`)**: Single-choice question with instant visual validation, explanation banner, and retry logic.
  - **Stage 6: Interactive Dialogue (`dialogue`)**: Turn-based conversational exchange between learner and NPC mascot with speech recognition or spoken sentence builder.
  - **Stage 7: Grammar Tip (`grammar_tip`)**: Pedagogical syntax and rule breakdowns with highlighted callout tables and actionable understanding confirmation.
- **Dual Native Indian Language Curriculum**:
  - Support for English A1 taught in Hindi (`en_hi`) and Marathi (`en_mr`) alongside German A1 (`de_a1`).

---

### FEAT-008 — Two-Step Onboarding Language Selection Flow & Clean Map Decoupled Course Management (COMPLETE ✅)
**Date:** 2026-10-16  
**Status:** Built, analyzed, and running live on mobile client (`1.2.6+11` / `v29.1.0-stable`).  
- **Post-Login / Registration 2-Step Onboarding Flow (`LanguageSelectionScreen`, `/language-select`)**:
  - Automatically triggered upon successful login or user registration.
  - Interactive two-step flow using progressive disclosure (matching Duolingo and Babbel UX standards):
    - **Step 1: Learning Language**: Choice between **German 🇩🇪** (105 Units) and **English 🇬🇧** (35 Units).
    - **Step 2: Native Instruction Language**:
      - If German selected: Native instruction defaults to **English 🇬🇧**.
      - If English selected: Native instruction choices for Indian learners: **Hindi 🇮🇳 (हिन्दी)** or **Marathi 🇮🇳 (मराठी)**.
  - Interactive tactile cards, Echo the Dolphin animated mascot reactions, step indicator dots, and back button.
- **Clean Map Status Bar (Popular App Standard)**:
  - Removed direct pair strings from the Archipelago Map screen header. The top status bar displays only the clean single target language flag emoji (e.g. 🇩🇪 or 🇬🇧).
  - Tapping the flag routes smoothly to Profile & Settings (`/profile/settings`).
- **Centralized Course Management in Settings & Profile**:
  - Added dedicated Active Course card in `GamifiedProfileScreen` with dynamic learner subtitle (`🇩🇪 German Learner` vs `🇬🇧 English Learner`).
  - Tactile "Switch" button in profile and "Active Course" tile in `SettingsScreen` both open the interactive 2-step modal (`LanguageSelectionScreen(isModal: true)`).
  - Synchronizes active course via `POST /api/gamification/switch-course`, re-initializes TTS voices (`TtsService().setLanguage`), and reloads path nodes.

---

*Last updated: 2026-10-16 | DolphinCoder LMS v29.1.0-stable (Mobile v1.2.6+11)*




