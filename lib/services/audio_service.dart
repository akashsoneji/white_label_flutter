import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:async';

class AudioService {
  static AudioPlayer? _audioPlayer;
  static bool _isInitialized = false;

  // Initialize the audio player with proper configuration for Android 12+
  static Future<void> _initializePlayer() async {
    if (!_isInitialized) {
      try {
        _audioPlayer = AudioPlayer();

        // Configure player for better Android 12+ compatibility
        await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer!.setPlayerMode(PlayerMode.lowLatency);

        // Set volume to maximum for better audio playback
        await _audioPlayer!.setVolume(1.0);

        _isInitialized = true;
        print('=== AUDIO SERVICE: Player initialized successfully ===');
        print(
          '=== AUDIO SERVICE: ReleaseMode=stop, PlayerMode=lowLatency, Volume=1.0 ===',
        );
      } catch (e) {
        print('=== AUDIO SERVICE: Error initializing player: $e ===');
        print('=== AUDIO SERVICE: Error type: ${e.runtimeType} ===');
        // Still mark as initialized to prevent infinite retries
        _isInitialized = true;
      }
    }
  }

  // Play no money sound
  static Future<void> playNoMoneySound() async {
    try {
      debugPrint('=== AUDIO SERVICE: Playing no money sound ===');

      await _initializePlayer();

      if (_audioPlayer == null) {
        debugPrint('Error: Audio player not initialized');
        return;
      }

      // Stop any currently playing audio
      await _audioPlayer!.stop();

      // Try different asset paths
      try {
        // First try: assets/audio/ path
        await _audioPlayer!.play(AssetSource('audio/no_money.wav'));
        debugPrint('Successfully played no money sound from assets/audio/!');
        return;
      } catch (e1) {
        debugPrint('Error with assets/audio/ path: $e1');
      }

      try {
        // Second try: direct asset path
        await _audioPlayer!.play(AssetSource('no_money.wav'));
        debugPrint('Successfully played no money sound from direct path!');
        return;
      } catch (e2) {
        debugPrint('Error with direct path: $e2');
      }

      try {
        // Third try: Android raw resources
        await _audioPlayer!.play(
          AssetSource('android/app/src/main/res/raw/no_money.wav'),
        );
        debugPrint('Successfully played no money sound from Android raw!');
        return;
      } catch (e3) {
        debugPrint('Error with Android raw path: $e3');
      }

      // Final fallback: play alert sound
      await playAlertSound();
    } catch (e) {
      debugPrint('Error playing no money sound: $e');
    }
  }

  // Play alert sound
  static Future<void> playAlertSound() async {
    try {
      debugPrint('=== AUDIO SERVICE: Playing alert sound ===');

      await _initializePlayer();

      if (_audioPlayer == null) {
        debugPrint('Error: Audio player not initialized');
        return;
      }

      await _audioPlayer!.stop();

      // Try different asset paths
      try {
        await _audioPlayer!.play(AssetSource('audio/alert_sound.mp3'));
        debugPrint('Successfully played alert sound from assets/audio/!');
        return;
      } catch (e1) {
        debugPrint('Error with assets/audio/ path: $e1');
      }

      try {
        await _audioPlayer!.play(
          AssetSource('android/app/src/main/res/raw/alert_sound.mp3'),
        );
        debugPrint('Successfully played alert sound from Android raw!');
        return;
      } catch (e2) {
        debugPrint('Error with Android raw path: $e2');
      }
    } catch (e) {
      debugPrint('Error playing alert sound: $e');
    }
  }

  // Play success sound with enhanced error handling for Android 12+
  static Future<void> playSuccessSound() async {
    try {
      print('🔊 === AUDIO SERVICE: Starting to play success sound ===');
      print('🔊 Platform: ${Platform.operatingSystem}');

      await _initializePlayer();

      if (_audioPlayer == null) {
        print('❌ AUDIO SERVICE: Error - Audio player is null');
        return;
      }

      print('🔊 AUDIO SERVICE: Stopping any currently playing audio...');
      try {
        await _audioPlayer!.stop();
        print('✅ AUDIO SERVICE: Stopped previous audio');
      } catch (stopError) {
        print('⚠️ AUDIO SERVICE: Error stopping previous audio: $stopError');
        // Continue anyway
      }

      // Ensure volume is set to maximum
      try {
        await _audioPlayer!.setVolume(1.0);
        print('🔊 AUDIO SERVICE: Volume set to 1.0');
      } catch (volumeError) {
        print('⚠️ AUDIO SERVICE: Error setting volume: $volumeError');
      }

      // Try primary asset path (most common)
      print(
        '🔊 AUDIO SERVICE: Attempting to play from assets/audio/success.mp3...',
      );
      try {
        await _audioPlayer!.play(AssetSource('audio/success.mp3'));
        print('✅ AUDIO SERVICE: Successfully started playing success sound!');

        // Listen for completion or errors (for debugging)
        _audioPlayer!.onPlayerStateChanged.listen((state) {
          print('🔊 AUDIO SERVICE: Player state changed: $state');
        });

        // Also listen for completion
        _audioPlayer!.onPlayerComplete.listen((_) {
          print('✅ AUDIO SERVICE: Audio playback completed');
        });

        return;
      } catch (e1) {
        print('❌ AUDIO SERVICE: Error with assets/audio/ path: $e1');
        print('❌ AUDIO SERVICE: Error type: ${e1.runtimeType}');
        print('❌ AUDIO SERVICE: Error details: ${e1.toString()}');
        if (e1 is Exception) {
          print('❌ AUDIO SERVICE: Exception: ${e1.toString()}');
        }
      }

      // Fallback: Try direct asset path
      print('🔊 AUDIO SERVICE: Attempting fallback path: success.mp3...');
      try {
        await _audioPlayer!.play(AssetSource('success.mp3'));
        print('✅ AUDIO SERVICE: Successfully played from fallback path!');
        return;
      } catch (e2) {
        print('❌ AUDIO SERVICE: Error with fallback path: $e2');
        print('❌ AUDIO SERVICE: Error type: ${e2.runtimeType}');
      }

      // Final fallback: Try alert sound
      print(
        '🔊 AUDIO SERVICE: Attempting to play alert sound as final fallback...',
      );
      try {
        await playAlertSound();
        print('✅ AUDIO SERVICE: Played alert sound as fallback');
      } catch (e3) {
        print('❌ AUDIO SERVICE: All audio playback attempts failed: $e3');
        print('❌ AUDIO SERVICE: Final error type: ${e3.runtimeType}');
      }
    } catch (e) {
      print('❌ AUDIO SERVICE: Critical error playing success sound: $e');
      print('❌ AUDIO SERVICE: Error type: ${e.runtimeType}');
      print('❌ AUDIO SERVICE: Error stack: ${StackTrace.current}');
    }
  }

  // Play one-click trading success sound - for rapid trading
  static Future<void> playOneClickTradeSuccessSound() async {
    try {
      print('🔊 === AUDIO SERVICE: Playing one-click trade success sound ===');

      await _initializePlayer();

      if (_audioPlayer == null) {
        print('❌ AUDIO SERVICE: Error - Audio player is null');
        return;
      }

      // Stop any currently playing audio
      try {
        await _audioPlayer!.stop();
      } catch (stopError) {
        print('⚠️ AUDIO SERVICE: Error stopping previous audio: $stopError');
      }

      // Set volume to maximum
      try {
        await _audioPlayer!.setVolume(1.0);
      } catch (volumeError) {
        print('⚠️ AUDIO SERVICE: Error setting volume: $volumeError');
      }

      // Play the one-click trade success sound
      try {
        await _audioPlayer!.play(
          AssetSource('audio/one_click_trade_success.mp3'),
        );
        print('✅ AUDIO SERVICE: Started playing one-click trade success sound');
        return;
      } catch (e1) {
        print(
          '❌ AUDIO SERVICE: Error playing one-click trade success sound: $e1',
        );
        // Try fallback path
        try {
          await _audioPlayer!.play(AssetSource('one_click_trade_success.mp3'));
          print('✅ AUDIO SERVICE: Played from fallback path');
          return;
        } catch (e2) {
          print('❌ AUDIO SERVICE: Fallback also failed: $e2');
          // Final fallback: use regular success sound
          // try {
          //   await _audioPlayer!.play(AssetSource('audio/success.mp3'));
          //   print('✅ AUDIO SERVICE: Using regular success sound as fallback');
          // } catch (e3) {
          //   print('❌ AUDIO SERVICE: All audio playback attempts failed: $e3');
          // }
        }
      }
    } catch (e) {
      print(
        '❌ AUDIO SERVICE: Critical error playing one-click trade success sound: $e',
      );
    }
  }

  // Play trade close sound
  static Future<void> playTradeCloseSound() async {
    try {
      debugPrint('=== AUDIO SERVICE: Playing trade close sound ===');

      await _initializePlayer();

      if (_audioPlayer == null) {
        debugPrint('Error: Audio player not initialized');
        return;
      }

      await _audioPlayer!.stop();

      // Try different asset paths
      try {
        await _audioPlayer!.play(AssetSource('audio/tradeclose.wav'));
        debugPrint('Successfully played trade close sound from assets/audio/!');
        return;
      } catch (e1) {
        debugPrint('Error with assets/audio/ path: $e1');
      }

      try {
        await _audioPlayer!.play(
          AssetSource('android/app/src/main/res/raw/tradeclose.wav'),
        );
        debugPrint('Successfully played trade close sound from Android raw!');
        return;
      } catch (e2) {
        debugPrint('Error with Android raw path: $e2');
      }
    } catch (e) {
      debugPrint('Error playing trade close sound: $e');
    }
  }

  // Test method
  static Future<void> testSound() async {
    debugPrint('=== AUDIO SERVICE: Testing sound playback ===');
    await playNoMoneySound();
  }

  // Dispose the audio player
  static Future<void> dispose() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
      _isInitialized = false;
      debugPrint('=== AUDIO SERVICE: Player disposed ===');
    }
  }
}
