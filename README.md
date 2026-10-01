# DolphinCoder LMS — Mobile Application 🐬

The cross-platform mobile client for DolphinCoder LMS, built with Flutter, Riverpod, and GoRouter.

## 🌟 Key Features
- **Gamified Coral Reef Archipelago**: Sinusoidal 3D island progression path with live oxygen health, streak flame counter, and pearls currency.
- **Interactive Multi-Stage Lessons (`LessonSessionScreen`)**:
  - **Word Match**: Fast pair matching tiles with instant tactile feedback.
  - **Listen & Tap**: Native audio streaming using `audioplayers` from `dolphincoder.com/api/notes/audio/db/:id`, interactive speaker button with play/pause toggling, animated listening dolphin mascot, and flexible sentence verification.
  - **Sentence Builder**: Draggable/tappable word token assembly with grammar verification.
  - **Sprechen Practice**: Voice dictation and pronunciation challenge with character reactions.
  - **Celebration**: Dopamine reward animations, XP, pearls, and audio chimes.
- **Interactive Karaoke Notes & Sprechen Mode**: Mobile word-level audio sync highlighting with continuous speech recognition (`ListenMode.dictation`).
- **Quizzes**: MCQ, Code-MCQ, and interactive Match the Pairs assessment.
- **Flashcards**: 3D interactive flip-card study mode with mastery progress tracking.
- **Activity History**: Localized study analytics, daily category badges, and active learning hours.

## 🚀 Running the App

```bash
cd app/dolphincoder
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk --debug
# or for release
flutter build apk --release
```
