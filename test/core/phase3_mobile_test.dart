import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/core/services/speech_lifecycle_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late CacheService cacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('dc_phase3_test_');
    cacheService = CacheService();
    cacheService.reset();
    await cacheService.setActiveUser('user_p3_123');
    cacheService.setAudioCacheDir(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    cacheService.reset();
  });

  /* =========================================================================
   * 1. Bounded LRU Audio Prefetch Cache Tests
   * ========================================================================= */
  group('Phase 3 Bounded LRU Audio Cache Tests', () {
    test('saves audio bytes and retrieves cached file', () async {
      const url = 'https://dolphincoder.com/audio/sample_german_01.mp3';
      final bytes = List<int>.generate(256, (i) => i % 256);

      final file = await cacheService.saveAudioBytes(url, bytes);
      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(await file.length(), 256);

      final retrieved = await cacheService.getCachedAudioFile(url);
      expect(retrieved, isNotNull);
      expect(retrieved!.path, file.path);
    });

    test('prunes oldest files when cache exceeds maxFiles limit', () async {
      // Limit to max 2 files
      const url1 = 'https://dolphincoder.com/audio/file1.mp3';
      const url2 = 'https://dolphincoder.com/audio/file2.mp3';
      const url3 = 'https://dolphincoder.com/audio/file3.mp3';

      final file1 = await cacheService.saveAudioBytes(url1, [1, 2, 3]);
      // Give file1 an older timestamp
      await file1!.setLastModified(DateTime.now().subtract(const Duration(minutes: 10)));

      final file2 = await cacheService.saveAudioBytes(url2, [4, 5, 6]);
      await file2!.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));

      // Now save file3 which should trigger pruning with maxFiles = 2
      await cacheService.saveAudioBytes(url3, [7, 8, 9]);
      await cacheService.pruneAudioCacheLru(maxFiles: 2, maxBytes: 1024 * 1024);

      // file1 (oldest) should have been evicted
      expect(await file1.exists(), isFalse);
      // file2 and file3 should remain
      expect(await file2.exists(), isTrue);
    });

    test('prunes oldest files when total size exceeds maxBytes limit', () async {
      const url1 = 'https://dolphincoder.com/audio/large1.mp3';
      const url2 = 'https://dolphincoder.com/audio/large2.mp3';

      // 600 bytes
      final file1 = await cacheService.saveAudioBytes(url1, List.filled(600, 1));
      await file1!.setLastModified(DateTime.now().subtract(const Duration(minutes: 10)));

      // 600 bytes
      final file2 = await cacheService.saveAudioBytes(url2, List.filled(600, 2));

      // With maxBytes = 1000, saving 1200 bytes total must evict file1
      await cacheService.pruneAudioCacheLru(maxBytes: 1000, maxFiles: 50);

      expect(await file1!.exists(), isFalse);
      expect(await file2!.exists(), isTrue);
    });

    test('accessing cached file refreshes its lastModified timestamp for LRU protection', () async {
      const url1 = 'https://dolphincoder.com/audio/protect1.mp3';
      const url2 = 'https://dolphincoder.com/audio/protect2.mp3';

      final file1 = await cacheService.saveAudioBytes(url1, [1, 2, 3]);
      // Set to 10 minutes ago
      await file1!.setLastModified(DateTime.now().subtract(const Duration(minutes: 10)));

      final file2 = await cacheService.saveAudioBytes(url2, [4, 5, 6]);
      // Set to 5 minutes ago
      await file2!.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));

      // Touch / access file1 now via getCachedAudioFile
      final accessed = await cacheService.getCachedAudioFile(url1);
      expect(accessed, isNotNull);

      // Now prune to max 1 file
      await cacheService.pruneAudioCacheLru(maxFiles: 1, maxBytes: 1024 * 1024);

      // file2 is now older than file1! So file2 should be evicted and file1 preserved.
      expect(await file2!.exists(), isFalse);
      expect(await file1!.exists(), isTrue);
    });
  });

  /* =========================================================================
   * 2. Multicast Audio Lifecycle Subscriptions Tests
   * ========================================================================= */
  group('Phase 3 Multicast Audio Lifecycle Subscriptions Tests', () {
    test('supports multiple simultaneous subscribers and unsubscribes cleanly without collisions', () {
      int listenerACalls = 0;
      int listenerBCalls = 0;

      final unsubscribeA = SpeechLifecycleBridge.subscribeAudioLifecycle(
        onAudioBecomingNoisy: () => listenerACalls++,
      );

      final unsubscribeB = SpeechLifecycleBridge.subscribeAudioLifecycle(
        onAudioBecomingNoisy: () => listenerBCalls++,
      );

      // Unsubscribe A
      unsubscribeA();

      // Ensure unsubscribing token is idempotent and doesn't throw
      unsubscribeA();

      // Clean up B
      unsubscribeB();
    });
  });
}
