# DolphinCoder LMS — Mobile Application 🐬

The cross-platform mobile companion for DolphinCoder LMS, built with Flutter 3, Riverpod 2, and GoRouter.
Package version: **1.2.6+11** (Git release tag: `v29.1.0-stable` / submodule: `v1.2.6`).

---

## 🌟 Key Features

### 1. Gamified 5-Tab Floating Shell & Onboarding Flow
- **2-Step Onboarding Language Selection (`LanguageSelectionScreen`, `/language-select`)**:
  - Automatically launches upon first-time user login or registration.
  - Interactive two-step flow:
    - **Step 1: Target Learning Language**: German 🇩🇪 or English 🇬🇧.
    - **Step 2: Native Language**: If German chosen -> English 🇬🇧; If English chosen -> Hindi 🇮🇳 (हिन्दी माध्यम) or Marathi 🇮🇳 (मराठी माध्यम).
  - Tactile selection cards, Echo the Dolphin mascot reactions, step indicator dots, and back button.
- **Learn (`/home`)**: 3D sinusoidal island archipelago map (`ArchipelagoMapScreen`) with active lesson progress, stars, chest checkpoints, oxygen gauge, and clean target language flag status bar (e.g. 🇩🇪 or 🇬🇧) without cluttering the map with paired strings. Tapping the flag routes to Profile/Settings.
- **Centralized Course Management**: Managed inside **Settings** (`settings_screen.dart`) and **Gamified Profile** (`gamified_profile_screen.dart` via `_buildActiveCourseCard`), triggering the 2-step modal (`LanguageSelectionScreen(isModal: true)`).
- **Parallel Course Switching & Shimmer Skeletons**: Switches courses in the background with immediate state reset, displaying animated island shimmer skeletons (`_IslandMapSkeleton`) without UI lockup, and preserving scroll position per course using `ValueKey(currentCourseId)`.
- **JIT On-Demand Lesson Fetching**: Island path endpoint (`GET /api/gamification/path`) is decoupled down to lightweight summary nodes (~35 KB vs 28.5 MB payload). Full multi-stage lesson content is fetched JIT on node tap via `GET /api/gamification/lesson/:id`.
- **Leagues (`/leagues`)**: Weekly ranked leaderboard (`LeaguesScreen`) based on accumulated study XP.
- **Quests (`/quests`)**: Daily and monthly milestones (`QuestsScreen`) rewarding pearls and XP.
- **Shop (`/shop`)**: Virtual economy store (`ShopScreen`) to refill oxygen (`🫧 5/5`) and freeze streaks using pearls.
- **Profile (`/profile`)**: Gamified learner overview (`GamifiedProfileScreen`) with dynamic learner subtitle (`🇩🇪 German Learner` vs `🇬🇧 English Learner`), active course card, streak stats, current league, and account settings.

### 2. Multi-Stage Interactive Lesson Session (`LessonSessionScreen`)
- **Dynamic Active Stage Filtering**: Session dynamically queues only authored curriculum stages (`_activeStageTypes`) out of 8 possible challenge types. Disabled or unauthored stages are omitted cleanly without skips or blank screens.
- **Real-Time Lady Voice TTS (`TtsService`)**: Built-in speech synthesis (`flutter_tts`) configured for native German (`de-DE`, female voice, 0.48 speech rate, 1.10 pitch) and English with persona selector:
  - **Stage 0: Word Match (`word_match`)**: Tapping any prompt word tile immediately articulates it in the lady's voice.
  - **Stage 1: Listen & Tap (`listen_tap`)**: Tapping/picking chips from `_listenBank` pronounces each chosen word in real-time.
  - **Stage 2: Sentence Builder / Fill-in-the-Blanks (`sentence_builder`)**: Picking word chips from `_builderBank` (e.g. *"Wie"*, *"geht's"*) pronounces each word on tap as it enters the sentence tray.
- **Full 8-Stage Interactive Runner**:
  - **Stage 0: Word Match (`word_match`)**: 4-pair interactive vocabulary matching grid with immediate TTS articulation, tactile selection feedback, and pair-elimination animations.
  - **Stage 1: Listen & Tap (`listen_tap`)**: High-fidelity sentence audio streaming (`audioplayers`) from `/api/notes/audio/db/:id` with tactile replay speaker button (`volume_up_rounded`), reactive dolphin mascot (`AnimatedDolphinMascot`), and scrambler chip rearrangement.
  - **Stage 2: Sentence Builder (`sentence_builder`)**: Fill-in-the-blank syntactic assembly with bank chips, instant word TTS feedback, Tray reset, and validation.
  - **Stage 3: Sprechen Lip-Sync (`sprechen`)**: One-time auto-play teacher demonstration (1s delay), real-time word-by-word karaoke highlighting (`karaokeData.words`), native German/English speech recognition (`speech_to_text`), and strict pronunciation passing threshold (`> 75% accuracy`).
  - **Stage 4: Flashcard Mastery (`flashcard`)**: 3D flip-card mastery stage with tactile prompt/definition cards.
  - **Stage 5: Quiz MCQ (`quiz_mcq`)**: Single-choice question with instant visual validation, explanation banner, and retry logic.
  - **Stage 6: Interactive Dialogue (`dialogue`)**: Turn-based conversational exchange between learner and NPC mascot with speech recognition or spoken sentence builder.
  - **Stage 7: Grammar Tip (`grammar_tip`)**: Pedagogical syntax and rule breakdowns with highlighted callout tables and actionable understanding confirmation.
- **Celebration & Rewards**: Flip animations, XP, pearls, and completion submission to `/api/gamification/complete-node`.

### 3. Core LMS Parity
- **Interactive Karaoke Notes & Sprechen**: Mobile word-level audio sync highlighting with continuous speech recognition (`ListenMode.dictation`).
- **Quizzes**: MCQ, Code-MCQ, **Match the Pairs (`MatchPairsWidget`)**, and **Dedicated Quiz Review (`QuizReviewScreen`)**.
- **Dual Subject & Topic Filtering**: Horizontal subject chips carousel and dynamic topic chips carousel in `quizzes_screen.dart`.
- **Flashcards**: 3D interactive flip-card study mode with mastery progress tracking.
- **Activity History**: Localized study analytics, daily category badges (**Today**, **Yesterday**, **Day Before Yesterday**), and active learning hours.
- **Audio Robustness**: Mounted lifecycle guards preventing async `setState` errors and offline fallback safety nets.

---

## 🚀 Running the App

```bash
cd app/dolphincoder
flutter pub get
flutter run                    # Debug mode (defaults to https://dolphincoder.com/api)
```

### Build APK & App Bundle
```bash
# Debug APK
flutter build apk --debug

# Production APK
flutter build apk --release

# Google Play App Bundle
flutter build appbundle --release
```
