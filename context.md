# DolphinCoder Flutter App — Context & Progress Log

> **Purpose:** Token-safe checkpoint. If conversation resets, read this file to resume exactly where we left off.
> **GitHub Repo:** https://github.com/amol410/DolphinFlutter.git
> **App Location:** `/Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/app/dolphincoder/`
> **IMPORTANT:** Do NOT touch `backend/` or `frontend/` — they are in production.

---

## 🗂 Source Documents

| File | Purpose |
|------|---------|
| `app/plan.md` | Full architecture plan (tech stack, design system, 20 screens) |
| `app/prompts.md` | Screen-by-screen AI prompts with full design specs |

---

## ✅ VERSION HISTORY

### v0.1.0 — Foundation (IN PROGRESS — commit this now)

**Status:** Core files written. `flutter pub get` not yet run. Git not yet initialized.

---

## 📁 Files Created So Far

### Root
- [x] `pubspec.yaml` — All dependencies from plan.md (riverpod, go_router, dio, flutter_secure_storage, shared_preferences, google_fonts, flutter_animate, cached_network_image, shimmer, flutter_html, webview_flutter, percent_indicator, image_picker, url_launcher, intl, timeago, etc.)
- [x] `lib/main.dart` — ProviderScope + DolphinCoderApp
- [x] `lib/app.dart` — MaterialApp.router with AppTheme.dark

### Core Layer (`lib/core/`)
- [x] `constants/app_constants.dart` — appName, tokenKey, userDataKey, apiBaseUrlKey
- [x] `constants/api_constants.dart` — All API endpoints, defaultBaseUrl = `http://10.0.2.2:5000/api` (Android emulator), productionBaseUrl, getBaseUrl() reads from SharedPreferences
- [x] `theme/app_colors.dart` — Full color palette (#0A0F1E background, #6366F1 primary, #A855F7 accent, note colors, deck gradient colors)
- [x] `theme/app_theme.dart` — Complete dark ThemeData with Google Fonts (Plus Jakarta Sans + Inter)
- [x] `network/api_exception.dart` — Custom ApiException class
- [x] `network/dio_client.dart` — Dio singleton with Bearer token interceptor, 401 auto-logout, reset()
- [x] `utils/validators.dart` — email, password, required, minLength, passwordStrength(returns 1/2/3)
- [x] `router/app_router.dart` — Complete go_router with ShellRoute (bottom nav), redirect guard (reads JWT), all 20 routes

### Shared Widgets (`lib/shared/widgets/`)
- [x] `glass_card.dart` — GlassCard widget (bg #111827, border white/0.08, BoxShadow with primary tint, InkWell tap)
- [x] `gradient_button.dart` — GradientButton (indigo→violet gradient, scale press animation, loading spinner, disabled state)
- [x] `app_text_field.dart` — AppTextField (label above, dark fill, indigo focus, error border)
- [x] `bottom_nav.dart` — AppShell with BottomNavigationBar (5 tabs: Home/Notes/Quizzes/Flashcards/Profile, active tab detection via GoRouterState)
- [x] `subject_badge.dart` — SubjectBadge (purple pill) + TopicBadge (blue pill)
- [x] `shimmer_loader.dart` — ShimmerBox, ShimmerCard, ShimmerGridLoader, ShimmerListLoader
- [x] `empty_state.dart` — EmptyState (emoji + title + subtitle + optional CTA button)

### Auth Feature (`lib/features/auth/`)
- [x] `data/models/user_model.dart` — UserModel (id, name, email, role, avatar, bio), initials getter, copyWith
- [x] `data/auth_repository.dart` — login(), register(), getMe(), updateProfile(), changePassword(), logout(), getToken(), getCachedUser(), _saveSession()
- [x] `providers/auth_provider.dart` — AuthState class, AuthNotifier (StateNotifier), authProvider
- [x] `screens/splash_screen.dart` — Pulsing glow animation, JWT check → /home or /onboarding
- [x] `screens/onboarding_screen.dart` — 3 slides (📚🧠🃏), animated dot indicators, Skip/Next/"Get Started"
- [x] `screens/login_screen.dart` — Email+password form, validation, Riverpod login, error snackbar
- [x] `screens/register_screen.dart` — Name+email+password, live password strength bar (3 segments), Riverpod register

### Data Models (other features)
- [x] `features/notes/data/models/note_model.dart` — NoteModel (id, title, content, contentType, subjectId, topic, tags, color, isPinned, subjectName, createdAt)
- [x] `features/videos/data/models/video_model.dart` — VideoModel + thumbnailUrl getter
- [x] `features/quizzes/data/models/quiz_model.dart` — QuizModel + QuizQuestion + AttemptModel + AttemptAnswer, difficulty getter
- [x] `features/flashcards/data/models/flashcard_model.dart` — FlashcardDeck + Flashcard

### Repositories (Step 1) ✅
- [x] `features/notes/data/notes_repository.dart` — getNotes (paginated + filter), getNoteById
- [x] `features/videos/data/videos_repository.dart` — getVideos (search + paginated), getVideoById
- [x] `features/quizzes/data/quiz_repository.dart` — getQuizzes, getQuizById, submitAttempt, getMyAttempts
- [x] `features/flashcards/data/flashcard_repository.dart` — getDecks, getDeckById, saveProgress

### Providers (Step 2) ✅
- [x] `features/notes/providers/notes_provider.dart` — NotesListNotifier (list, loadMore, search, filterSubject/Topic), noteDetailProvider.family
- [x] `features/videos/providers/videos_provider.dart` — VideosListNotifier + videoDetailProvider.family
- [x] `features/quizzes/providers/quiz_provider.dart` — QuizzesListNotifier + quizDetailProvider + myAttemptsProvider + QuizTakeNotifier (autoDispose, session state)
- [x] `features/flashcards/providers/flashcard_provider.dart` — flashcardListProvider + deckDetailProvider + StudySessionNotifier (autoDispose)

### Dashboard (Step 3) ✅
- [x] `features/dashboard/screens/dashboard_screen.dart` — SliverAppBar greeting, 4-stat row, recent notes horizontal list, featured quiz card, latest video card, flashcard decks horizontal list

### Notes Screens (Step 4) ✅
- [x] `features/notes/screens/notes_screen.dart` — search debounce, subject+topic filter chips, 2-col grid, infinite scroll, pull-to-refresh, pin icon, colored border NoteCard
- [x] `features/notes/screens/note_detail_screen.dart` — SliverAppBar with note color gradient, flutter_html rich text, WebView for HTML slides, fullscreen toggle, tags/badges

### Videos Screens (Step 5) ✅
- [x] `features/videos/screens/videos_screen.dart` — search, 2-col grid, YouTube thumbnail with play overlay, view count
- [x] `features/videos/screens/video_detail_screen.dart` — YouTube embed via WebView (no AppBar), back button overlay, description/tags

### Quizzes Screens (Step 6) ✅
- [x] `features/quizzes/screens/quizzes_screen.dart` — search, subject chips, QuizCard (difficulty badge, stats row, take quiz button)
- [x] `features/quizzes/screens/quiz_detail_screen.dart` — hero card, 2x2 info grid, attempt chips, rules ExpansionTile, start button
- [x] `features/quizzes/screens/quiz_take_screen.dart` — full screen, circular timer, question cards, option selection, mark for review, bottom nav (prev/navigator/next), ModalBottomSheet question grid, submit with confirmation
- [x] `features/quizzes/screens/quiz_result_screen.dart` — animated % ring, PASS/FAIL badge, stats row, question review with explanations, retake/back buttons

### Flashcards Screens (Step 7) ✅
- [x] `features/flashcards/screens/flashcards_screen.dart` — 2-col gradient DeckCard grid with decorative circles, card count badge
- [x] `features/flashcards/screens/study_screen.dart` — full screen, AnimatedSwitcher flip card, Still Learning/Got It buttons, mastery % completion screen, WillPopScope saves progress

### Profile Screens (Step 8) ✅
- [x] `features/profile/screens/profile_screen.dart` — gradient avatar, role badge, stats row, menu items, logout confirm dialog
- [x] `features/profile/screens/edit_profile_screen.dart` — pre-filled name+bio, save via PUT /auth/profile
- [x] `features/profile/screens/change_password_screen.dart` — 3 password fields with eye toggles, strength bar, validation
- [x] `features/profile/screens/settings_screen.dart` — General, Developer (API URL editor), Cache (clear), About (version/rate/links)

### Android Config (Step 9) ✅
- [x] `android/app/src/main/AndroidManifest.xml` — INTERNET + CAMERA + READ/WRITE_EXTERNAL_STORAGE permissions
- [x] `android/app/build.gradle.kts` — minSdk = 23

---

## ❌ NOT YET DONE (Resume from here)

### Repositories (need to write)
- [ ] `features/notes/data/notes_repository.dart`
- [ ] `features/videos/data/videos_repository.dart`
- [ ] `features/quizzes/data/quiz_repository.dart`
- [ ] `features/flashcards/data/flashcard_repository.dart`

### Providers (need to write)
- [ ] `features/notes/providers/notes_provider.dart`
- [ ] `features/videos/providers/videos_provider.dart`
- [ ] `features/quizzes/providers/quiz_provider.dart`
- [ ] `features/flashcards/providers/flashcard_provider.dart`

### Screens (need to write)
- [ ] `features/dashboard/screens/dashboard_screen.dart` — Stats row, recent notes, featured quiz, latest video, flashcard decks
- [ ] `features/notes/screens/notes_screen.dart` — Search, subject chips, masonry grid, pagination
- [ ] `features/notes/screens/note_detail_screen.dart` — flutter_html content, WebView for html type
- [ ] `features/videos/screens/videos_screen.dart` — Search, 2-col grid, YouTube thumbnails
- [ ] `features/videos/screens/video_detail_screen.dart` — YouTube player (webview-based)
- [ ] `features/quizzes/screens/quizzes_screen.dart` — Search + filter, quiz cards list
- [ ] `features/quizzes/screens/quiz_detail_screen.dart` — Info grid, past attempts, start quiz
- [ ] `features/quizzes/screens/quiz_take_screen.dart` — FULL SCREEN timer, question cards, navigator sheet
- [ ] `features/quizzes/screens/quiz_result_screen.dart` — Score ring, stats, question review
- [ ] `features/flashcards/screens/flashcards_screen.dart` — Deck grid with gradient cards
- [ ] `features/flashcards/screens/study_screen.dart` — FULL SCREEN flip card, Got It / Still Learning
- [ ] `features/profile/screens/profile_screen.dart` — Avatar, stats, menu items
- [ ] `features/profile/screens/edit_profile_screen.dart` — Name + bio form
- [ ] `features/profile/screens/change_password_screen.dart` — 3 password fields
- [ ] `features/profile/screens/settings_screen.dart` — Notifications, API URL, cache, about

### Android Config
- [ ] `android/app/src/main/AndroidManifest.xml` — Add INTERNET permission
- [ ] `android/app/build.gradle` — minSdkVersion 23

### Git Setup
- [ ] `git init` in dolphincoder/
- [ ] `git remote add origin https://github.com/amol410/DolphinFlutter.git`
- [ ] Commit v0.1.0 (Foundation)
- [ ] `flutter pub get`
- [ ] `flutter analyze`

---

## 🔧 How to Resume

1. Read this file first
2. Check "❌ NOT YET DONE" section
3. Start from **Repositories** → then **Providers** → then **Screens**
4. After each phase, commit with version tag

---

## 📱 How to Simulate / Run the App

### Prerequisites
```bash
flutter doctor          # ensure Flutter is installed
flutter devices         # list available simulators/emulators
```

### Android (Emulator)
```bash
# Start Android emulator from Android Studio or:
emulator -avd <avd_name>

# Run app
cd /Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/app/dolphincoder
flutter run
```

> **API Note:** Android emulator uses `10.0.2.2` to reach your Mac's localhost.
> Backend must be running on port 5000. The app is pre-configured for this.

### iOS (Simulator)
```bash
open -a Simulator
flutter run
```

### Change API URL at Runtime
- Go to **Profile → Settings → API Base URL**
- Change to your production URL: `https://api.dolphincoder.com/api`
- Restart the app

### Hot Reload / Restart
```bash
# While running, press:
r   → hot reload
R   → hot restart
q   → quit
```

---

## 🎨 Design System Quick Reference

| Token | Value |
|-------|-------|
| Background | `#0A0F1E` |
| Surface | `#111827` |
| Surface2 | `#1A2235` |
| Primary (Indigo) | `#6366F1` |
| Accent (Violet) | `#A855F7` |
| Success | `#10B981` |
| Error | `#EF4444` |
| Warning | `#F59E0B` |
| Heading Font | Plus Jakarta Sans |
| Body Font | Inter |

---

## 🔗 Key API Endpoints (Backend at port 5000)

```
POST /api/auth/login       { email, password } → { token, user }
POST /api/auth/register    { name, email, password } → { token, user }
GET  /api/auth/me          (Bearer) → { user }
GET  /api/subjects         → [{ id, name, topics }]
GET  /api/notes            ?q=&subject=&topic=&page=&limit=
GET  /api/notes/:id        → note detail
GET  /api/videos           ?q=&page=&limit=
GET  /api/videos/:id       → video detail
GET  /api/quizzes          ?q=&subject=&topic=&page=&limit=
GET  /api/quizzes/:id      → quiz with questions
POST /api/quizzes/:id/attempt  { answers, timeTaken }
GET  /api/quizzes/:id/attempts → my attempts
GET  /api/flashcards       → decks list
GET  /api/flashcards/:id   → deck + cards
GET  /api/flashcards/:id/progress
POST /api/flashcards/:id/progress  { cardResults, masteredCount }
PUT  /api/auth/profile     { name, bio }
PUT  /api/auth/password    { currentPassword, newPassword }
```

---

---

## 🚀 NEXT STEPS (Exact order to follow)

> Pick up from Step 1 below. Each step = one file to write. Do them in order.

---

### STEP 1 — Repositories (Data Layer)

Write these 4 files next. Each one wraps Dio calls and returns typed models.

#### `features/notes/data/notes_repository.dart`
```dart
// Methods needed:
// Future<List<NoteModel>> getNotes({String? q, String? subject, String? topic, int page = 1, int limit = 12})
// Future<NoteModel> getNoteById(String id)
```

#### `features/videos/data/videos_repository.dart`
```dart
// Methods needed:
// Future<List<VideoModel>> getVideos({String? q, int page = 1, int limit = 12})
// Future<VideoModel> getVideoById(String id)
```

#### `features/quizzes/data/quiz_repository.dart`
```dart
// Methods needed:
// Future<List<QuizModel>> getQuizzes({String? q, String? subject, String? topic, int page = 1})
// Future<QuizModel> getQuizById(String id)
// Future<AttemptModel> submitAttempt(String id, List<Map> answers, int timeTaken)
// Future<List<AttemptModel>> getMyAttempts(String quizId)
```

#### `features/flashcards/data/flashcard_repository.dart`
```dart
// Methods needed:
// Future<List<FlashcardDeck>> getDecks()
// Future<FlashcardDeck> getDeckById(String id)
// Future<void> saveProgress(String id, Map<String,String> cardResults, int masteredCount)
```

---

### STEP 2 — Providers (State Layer)

One Riverpod provider file per feature.

#### `features/notes/providers/notes_provider.dart`
- `notesRepositoryProvider` (Provider)
- `notesListProvider` (StateNotifierProvider) — holds list, loading, pagination state
- `noteDetailProvider(id)` (FutureProvider.family)

#### `features/videos/providers/videos_provider.dart`
- Same pattern: list provider + detail provider

#### `features/quizzes/providers/quiz_provider.dart`
- `quizzesListProvider` (StateNotifierProvider)
- `quizDetailProvider(id)` (FutureProvider.family)
- `myAttemptsProvider(id)` (FutureProvider.family)
- `quizTakeNotifier` (StateNotifier) — manages quiz session state (currentIndex, answers, timer, markedForReview)

#### `features/flashcards/providers/flashcard_provider.dart`
- `flashcardListProvider` (FutureProvider)
- `deckDetailProvider(id)` (FutureProvider.family)
- `studySessionNotifier` (StateNotifier) — manages flip, results, isComplete

---

### STEP 3 — Dashboard Screen

**File:** `features/dashboard/screens/dashboard_screen.dart`

Key sections to build:
1. `SliverAppBar` — greeting with hour-based "Good morning/afternoon/evening", initials avatar
2. Stats row — 4 mini GlassCards (Notes / Videos / Quizzes / Flashcards count)
3. "📚 Recent Notes" — horizontal ListView, NoteCard widget, tap → `/notes/:id`
4. "🧠 Featured Quiz" — single QuizCard, "Take Quiz" button
5. "🎬 Latest Video" — YouTube thumbnail card, tap → `/videos/:id`
6. "🃏 Flashcard Decks" — horizontal ListView, DeckCard widget

API calls: GET /notes?limit=5, GET /quizzes?limit=1, GET /videos?limit=1, GET /flashcards?limit=4

---

### STEP 4 — Notes Screens

**File 1:** `features/notes/screens/notes_screen.dart`
- Search bar with 400ms debounce
- Subject filter chips (GET /subjects) → animated topic sub-chips
- RefreshIndicator + GridView.builder (2 col)
- NoteCard: left colored border, pin icon, subject badge, date
- Infinite scroll pagination

**File 2:** `features/notes/screens/note_detail_screen.dart`
- SliverAppBar with gradient from note.color
- flutter_html for richtext/docx content (white text, code blocks dark)
- WebViewWidget in 16:9 for html contentType
- Tags row, subject/topic badges

---

### STEP 5 — Videos Screens

**File 1:** `features/videos/screens/videos_screen.dart`
- Search bar
- GridView 2-col with VideoCard
- VideoCard: CachedNetworkImage thumbnail, play icon overlay, title, view count

**File 2:** `features/videos/screens/video_detail_screen.dart`
- NO AppBar — back button overlay
- YouTube player via WebView (use `webview_flutter` loading `https://www.youtube.com/embed/{id}?autoplay=1`)
- Below: title, views, description, tags, subject badges

---

### STEP 6 — Quizzes Screens (4 screens — most complex)

**File 1:** `features/quizzes/screens/quizzes_screen.dart`
- Search + subject/topic filter chips
- ListView of QuizCard widgets
- QuizCard: gradient icon, difficulty badge, time badge, subject+topic, stats row, "Take Quiz" button

**File 2:** `features/quizzes/screens/quiz_detail_screen.dart`
- Hero card, info grid (2x2), previous attempts chips, rules ExpansionTile
- Large "Start Quiz" gradient button

**File 3:** `features/quizzes/screens/quiz_take_screen.dart` ⚠️ MOST COMPLEX
- Full screen (no bottom nav)
- Stack: top bar (X + title + circular timer), progress bar, question card, options list
- Mark for Review toggle
- Bottom: Prev / Question Navigator / Next buttons
- ModalBottomSheet: color-coded question grid
- On submit: AlertDialog if unanswered → POST attempt → navigate to result

**File 4:** `features/quizzes/screens/quiz_result_screen.dart`
- Animated CircularPercentIndicator score ring (green/red)
- PASSED/FAILED badge
- Stats row (correct, wrong, skipped, time)
- Question review list (accordion with green/red borders)
- Retake + Back buttons

---

### STEP 7 — Flashcards Screens

**File 1:** `features/flashcards/screens/flashcards_screen.dart`
- GridView 2-col of DeckCard
- DeckCard: gradient bg by deck.color, decorative circles, card count, "Study →"
- Pull-to-refresh, shimmer loading

**File 2:** `features/flashcards/screens/study_screen.dart` ⚠️ COMPLEX
- Full screen (no bottom nav)
- Top bar: X close, deck name, progress counter
- Flip card with 3D AnimatedSwitcher (front: question, back: answer)
- Bottom: Still Learning (red) / Got It (green) buttons (visible when flipped)
- Completion screen: mastery % ring + "Study Again" + "Back to Decks"
- On pop: POST /flashcards/:id/progress

---

### STEP 8 — Profile Screens (4 screens)

**File 1:** `features/profile/screens/profile_screen.dart`
- Avatar with initials fallback (CachedNetworkImage if avatar exists)
- Name, email, role badge (student/trainer/admin)
- Stats row: Quizzes / Passed / Decks
- Menu: Edit Profile, Change Password, Videos, Settings, Logout (AlertDialog confirm)

**File 2:** `features/profile/screens/edit_profile_screen.dart`
- Avatar display + "Change Photo" button (ImagePicker)
- Name + Bio (multiline) fields, pre-filled
- PUT /auth/profile on save

**File 3:** `features/profile/screens/change_password_screen.dart`
- Current + New + Confirm password fields (all obscureText with eye toggles)
- Password strength bar on new password
- PUT /auth/password on save

**File 4:** `features/profile/screens/settings_screen.dart`
- Sections: General, Developer (API URL editable), Cache, About
- ListTile for each item, glass card per section

---

### STEP 9 — Android Manifest + Build Config

#### `android/app/src/main/AndroidManifest.xml`
Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

#### `android/app/build.gradle`
Change:
```groovy
minSdkVersion 21  →  minSdkVersion 23
```

---

### STEP 10 — Git Push (v0.1.0)

```bash
cd /Users/cms/Desktop/Code/mern/lms_speedup/MERNLMS/app/dolphincoder

# Initialize git
git init
git remote add origin https://github.com/amol410/DolphinFlutter.git

# Install packages
flutter pub get

# Check for errors
flutter analyze

# Commit v0.1.0 — Foundation
git add .
git commit -m "v0.1.0 — Foundation: theme, core, auth screens, shared widgets, models"
git push -u origin main --force
```

After v0.1.0 is pushed, continue building Step 3 onward and commit each phase:
```
v0.2.0 — Dashboard + Notes
v0.3.0 — Videos + Quizzes
v0.4.0 — Flashcards + Profile
v1.0.0 — Polish + Android config
```

---

*Last updated: 2026-08-12 | Conversation ID: 7438c229-1d4c-48c7-bf0f-f128e3d11ee6*
