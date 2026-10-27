import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechPreferencesState {
  final bool isSpeakingExercisesEnabled;
  final int? mutedUntilTimestampMs;

  const SpeechPreferencesState({
    this.isSpeakingExercisesEnabled = true,
    this.mutedUntilTimestampMs,
  });

  bool get isCurrentlyMuted {
    if (!isSpeakingExercisesEnabled) return true;
    if (mutedUntilTimestampMs == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < mutedUntilTimestampMs!;
  }

  SpeechPreferencesState copyWith({
    bool? isSpeakingExercisesEnabled,
    int? mutedUntilTimestampMs,
    bool clearMute = false,
  }) {
    return SpeechPreferencesState(
      isSpeakingExercisesEnabled:
          isSpeakingExercisesEnabled ?? this.isSpeakingExercisesEnabled,
      mutedUntilTimestampMs: clearMute
          ? null
          : (mutedUntilTimestampMs ?? this.mutedUntilTimestampMs),
    );
  }
}

class SpeechPreferencesNotifier extends StateNotifier<SpeechPreferencesState> {
  static const _prefKeyEnabled = 'pref_speaking_exercises_enabled';
  static const _prefKeyMutedUntil = 'pref_speaking_muted_until_ms';

  SpeechPreferencesNotifier() : super(const SpeechPreferencesState()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefKeyEnabled) ?? true;
      final mutedUntil = prefs.getInt(_prefKeyMutedUntil);
      state = SpeechPreferencesState(
        isSpeakingExercisesEnabled: enabled,
        mutedUntilTimestampMs: mutedUntil,
      );
    } catch (_) {}
  }

  /// Snooze speaking exercises for a given duration (default 1 hour like Duolingo)
  Future<void> snoozeSpeakingExercises({
    Duration duration = const Duration(hours: 1),
  }) async {
    final muteUntil =
        DateTime.now().add(duration).millisecondsSinceEpoch;
    state = state.copyWith(mutedUntilTimestampMs: muteUntil);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeyMutedUntil, muteUntil);
    } catch (_) {}
  }

  /// Unmute speaking exercises
  Future<void> unmuteSpeakingExercises() async {
    state = state.copyWith(clearMute: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyMutedUntil);
    } catch (_) {}
  }

  /// Toggle speaking exercises permanently on/off
  Future<void> setSpeakingExercisesEnabled(bool enabled) async {
    state = state.copyWith(isSpeakingExercisesEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, enabled);
    } catch (_) {}
  }
}

final speechPreferencesProvider =
    StateNotifierProvider<SpeechPreferencesNotifier, SpeechPreferencesState>(
  (ref) => SpeechPreferencesNotifier(),
);
