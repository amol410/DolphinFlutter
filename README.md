# DolphinCoder LMS — Mobile Application 🐬

The cross-platform mobile companion for DolphinCoder LMS, built with Flutter 3, Riverpod 2, and GoRouter.
Package version: **1.2.5+10** (Git release tag: `v25.0.0` / submodule: `v1.2.5`).

---

## 🌟 Key Features

### 1. Gamified 5-Tab Floating Shell (`bottom_nav.dart`)
- **Learn (`/home`)**: 3D sinusoidal island archipelago map (`ArchipelagoMapScreen`) with active lesson progress, stars, chest checkpoints, and oxygen gauge.
- **Leagues (`/leagues`)**: Weekly ranked leaderboard (`LeaguesScreen`) based on accumulated study XP.
- **Quests (`/quests`)**: Daily and monthly milestones (`QuestsScreen`) rewarding pearls and XP.
- **Shop (`/shop`)**: Virtual economy store (`ShopScreen`) to refill oxygen (`🫧 5/5`) and freeze streaks using pearls.
- **Profile (`/profile`)**: Gamified learner overview (`GamifiedProfileScreen`) with streak stats, current league, and account settings.

### 2. Multi-Stage Interactive Lesson Session (`LessonSessionScreen`)
- **Dynamic Active Stage Filtering**: Session dynamically queues only authored curriculum stages (`_activeStageTypes`). Disabled stages are omitted cleanly.
- **Stage 0: Word Match (`word_match`)**: Fast pair matching tiles with instant tactile feedback and dynamic JSON parsing.
- **Stage 1: Listen & Tap (`listen_tap`)**:
  - Full-sentence audio streaming using `audioplayers` from `/api/notes/audio/db/:id`.
  - **Tactile Speaker Button**: Re-plays the full sentence cleanly from 0:00 on every tap with permanent `volume_up_rounded` iconography.
  - **Pure Sequencing Word Bank**: Word chips operate as tactile sequence arrangers without sound distraction, letting learners focus on the spoken sentence.
  - Attentive animated dolphin mascot (`AnimatedDolphinMascot`) wearing headphones.
- **Stage 2: Sentence Builder (`sentence_builder`)**: Draggable/tappable word token assembly with grammar verification.
- **Stage 3: Sprechen Lip-Sync (`sprechen`)**:
  - One-time auto-play teacher demonstration after a 1-second delay.
  - Synchronized real-time karaoke highlighting (`karaokeData.words`) in the speech bubble.
  - **Native German Speech Recognition (`de_DE`)**: Configured strictly with `speech_to_text` for native German dictation.
  - Strict passing threshold (`> 75% accuracy`).
- **Stage 4: Celebration & Rewards**: Flip animations, XP, pearls, and completion submission to `/api/gamification/complete-node`.

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
