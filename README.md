# DolphinCoder LMS — Mobile Application 🐬

The cross-platform mobile companion for DolphinCoder LMS, built with Flutter 3, Riverpod 2, and GoRouter.
Package version: **1.2.12+18** (Git submodule: `889662b` / production release: `v33.0.0-stable`).

---

## 🌟 Key Features

### 1. 5-Phase Speech Lifecycle & Audio-Visual Feedback
- **5-Phase Finite State Machine (`SpeechRecognitionService`)**:
  - `Idle`: Microphone dormant, zero battery/audio focus consumption.
  - `Armed`: Pre-flight permission verification, 3-tier engine negotiation, acoustic dampening cooldown (400ms).
  - `Listening`: Active audio capture, real-time RMS sound level stream driving **animated sound wave ripples**.
  - `Processing`: Audio stream closure, double-tap gating preventing duplicate evaluation requests, dynamic phonetic normalization.
  - `Evaluated`: Pronunciation scoring against passing benchmark ($\ge 75\%$), celebratory **confetti shower** (`ConfettiWidget`) on success, or gentle constructive retry feedback.
- **Stationary Machine Speech & Word Scorecard**: Complete sentence validation and student end-of-sentence word-level scorecard highlighting passed and missed phonemes.
- **Tactile Audio-Haptic Feedback (`SoundEffectsService`)**: System haptics synchronized with sound effects for card taps, bubble selections, pair elimination, and celebration fanfares.
- **Turtle Speed Audio (0.75x)**: Normal (1.0x) and turtle slow (0.75x) playback toggles across vocabulary and listening drills.

### 2. Native Android Speech Bridge & 3-Tier Fallback (`MainActivity.kt`)
- **MethodChannel (`com.dolphincoder.lms/speech_lifecycle`)**:
  - **Tier 1 (Google QuickSearchBox)**: Resolves `com.google.android.googlequicksearchbox` for high-accuracy neural ASR.
  - **Tier 2 (OEM System Service)**: Falls back dynamically to device OEM speech recognition services (Samsung, Xiaomi, Oppo, Vivo).
  - **Tier 3 (Default Platform Recognizer)**: Generic platform recognizer safety net.
- **Hardware Leak Prevention**: Reflective detachment of `SpeechToTextPlugin.speechRecognizer` on `onDestroy`, `onPause`, and `onStop`, eliminating Android Binder death (`DEAD_OBJECT`) and `AudioRecord` hardware lockups.
- **Bluetooth SCO Routing**: Automatically redirects microphone input to Bluetooth headsets when connected.
- **Becoming Noisy Receiver**: Automatically pauses audio playback when headphones are disconnected.

### 3. Gamified 5-Tab Floating Shell & Onboarding Flow
- **2-Step Onboarding Language Selection (`LanguageSelectionScreen`, `/language-select`)**:
  - Automatically launches upon first-time user login or registration.
  - Interactive two-step flow:
    - **Step 1: Target Learning Language**: German 🇩🇪 or English 🇬🇧.
    - **Step 2: Native Language**: If German chosen -> English 🇬🇧; If English chosen -> Hindi 🇮🇳 (हिन्दी माध्यम) or Marathi 🇮🇳 (मराठी माध्यम).
  - Tactile selection cards, Echo the Dolphin mascot reactions, step indicator dots, and back button.
- **Learn (`/home`)**: 3D sinusoidal island archipelago map (`ArchipelagoMapScreen`) with active lesson progress, stars, chest checkpoints, oxygen gauge (`🫧 5/5`), and clean target language flag status bar (e.g. 🇩🇪 or 🇬🇧).
- **Centralized Course Management**: Managed inside **Settings** (`settings_screen.dart`) and **Gamified Profile** (`gamified_profile_screen.dart` via `_buildActiveCourseCard`), triggering the 2-step modal (`LanguageSelectionScreen(isModal: true)`).
- **Decoupled JIT Loading & Shimmer Skeletons**: Island path endpoint (`GET /api/gamification/path`) loads lightweight summary nodes (~35 KB vs 28.5 MB payload). Full multi-stage lesson content is fetched JIT on node tap via `GET /api/gamification/lesson/:id`.
- **Leagues (`/leagues`)**: Weekly ranked leaderboard (`LeaguesScreen`) based on accumulated study XP.
- **Quests (`/quests`)**: Daily and monthly milestones (`QuestsScreen`) rewarding pearls and XP.
- **Shop (`/shop`)**: Virtual economy store (`ShopScreen`) to refill oxygen (`🫧 5/5`) and freeze streaks using pearls.
- **Profile (`/profile`)**: Gamified learner overview (`GamifiedProfileScreen`) with active course card, streak stats, current league, and account settings.

### 4. Multi-Stage Interactive Lesson Session (`LessonSessionScreen`)
- **Full 8-Stage Interactive Runner**:
  - **Stage 0: Word Match (`word_match`)**: 3D interactive vocabulary matching grid with immediate TTS articulation, tactile selection feedback, and pair-elimination animations.
  - **Stage 1: Listen & Tap (`listen_tap`)**: High-fidelity sentence audio streaming (`audioplayers`) from `/api/notes/audio/db/:id` with tactile replay speaker button, reactive dolphin mascot, and scrambler chip rearrangement.
  - **Stage 2: Sentence Builder (`sentence_builder`)**: Fill-in-the-blank syntactic assembly with bank chips, instant word TTS feedback, tray reset, and syntax validation.
  - **Stage 3: Sprechen Lip-Sync (`sprechen`)**: One-time auto-play teacher demonstration, real-time word-by-word karaoke highlighting, native German/English speech recognition (`speech_to_text`), and strict pronunciation passing threshold ($\ge 75\%$).
  - **Stage 4: Flashcard Mastery (`flashcard`)**: 3D flip-card mastery stage with tactile prompt/definition cards.
  - **Stage 5: Quiz MCQ (`quiz_mcq`)**: Single-choice question with instant visual validation, explanation banner, and retry logic.
  - **Stage 6: Interactive Dialogue (`dialogue`)**: Turn-based conversational exchange between learner and NPC mascot with speech recognition or spoken sentence builder.
  - **Stage 7: Grammar Tip (`grammar_tip`)**: Pedagogical syntax and rule breakdowns with highlighted callout tables and actionable understanding confirmation.

### 5. Google AdMob Monetization Architecture (`AdService`)
- **Verified Production Ad Units**:
  - App Open Ad: `ca-app-pub-6038618318911032/8348873402`
  - Banner Ad: `ca-app-pub-6038618318911032/6281729064`
  - Interstitial Ad: `ca-app-pub-6038618318911032/5691039801` (Triggered every 3 completed lessons)
  - Rewarded Video Ad: `ca-app-pub-6038618318911032/2144704383` (Awards +2 Oxygen Bubbles, capped at 6 claims/day)
- **Crawler Verification**: Verified through `https://dolphincoder.com/app-ads.txt`.

---

## 🛠️ Running & Building the Mobile App

### Prerequisites
- Flutter SDK 3.22+
- Android Studio / Android SDK 34 (API 34)
- Java 17 LTS

### Development
```bash
cd app/dolphincoder
flutter pub get
flutter run                    # Debug mode (defaults to https://dolphincoder.com/api)
```

### Production Release Builds
```bash
# Build standalone release APK
flutter build apk --release

# Build Google Play release App Bundle (.aab)
flutter build appbundle --release
```

---

## 📂 Directory Layout (`lib/`)

```
app/dolphincoder/lib/
├── app.dart                          # Root MaterialApp.router with AMOLED Dark & Oceanic Light themes
├── main.dart                         # Entry point, ProviderScope initialization, MobileAds init
├── core/
│   ├── constants/
│   │   ├── api_constants.dart        # Endpoints, baseUrl configuration, timeouts
│   │   └── app_colors.dart           # AMOLED Dark & Oceanic Light color tokens
│   ├── network/
│   │   ├── dio_client.dart           # Dio HTTP client, JWT auth interceptor, memory token cache
│   │   └── latency_interceptor.dart  # Real-time network latency tracking
│   ├── providers/
│   │   └── shared_preferences_provider.dart # SharedPreferences DI wrapper
│   ├── router/
│   │   └── app_router.dart           # Declarative GoRouter configuration with auth guards
│   ├── services/
│   │   ├── ad_service.dart           # Google AdMob manager (App Open, Banner, Interstitial, Rewarded)
│   │   ├── cache_service.dart        # Tier-2 local storage & Stale-While-Revalidate caching
│   │   ├── prefetch_service.dart     # Predictive background lesson pre-warming
│   │   ├── pronunciation_evaluator.dart # Dynamic programming Levenshtein & Soundex scoring
│   │   ├── sound_effects_service.dart   # Audio-haptic feedback & fanfare synthesizers
│   │   ├── speech_lifecycle_bridge.dart # Native MethodChannel bridge for Android lifecycle
│   │   ├── speech_recognition_service.dart # 5-phase speech state machine & visualizer stream
│   │   ├── tts_service.dart          # Low-latency speech synthesis & audio pre-caching
│   │   └── version_check_service.dart# Google Play store force update checker
│   ├── theme/
│   │   └── app_theme.dart            # Material 3 dark/light themes & typography
│   └── utils/
│       ├── audio_utils.dart          # Audio normalization & pre-roll handlers
│       └── string_utils.dart         # Umlaut & diacritic text helpers
├── features/
│   ├── auth/                         # Splash, Login, Register, Language selection
│   ├── dashboard/                    # Study summary, today's performance, streaks
│   ├── flashcards/                   # 3D interactive flip-card study mode
│   ├── gamification/                 # Archipelago map, 8-stage lesson runner, confetti, shop, quests, leagues
│   ├── notes/                        # Tiptap note reader, sandboxed slides, karaoke reader
│   ├── profile/                      # Gamified profile, active course switcher, settings
│   ├── quizzes/                      # Quizzes list, timer runner, match-pairs widget, quiz review
│   └── videos/                       # YouTube player screen & video catalogs
└── shared/
    └── widgets/                      # Buttons, cards, skeletons, dolphin mascot
```
