import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioServiceV2 {
  static final Map<String, AudioPlayer> _players = {};
  static bool _isInitialized = false;

  // Initialize audio service
  static Future<void> initialize() async {
    if (!_isInitialized) {
      // Pre-create players for each sound
      _players['no_money'] = AudioPlayer();
      _players['alert'] = AudioPlayer();
      _players['success'] = AudioPlayer();
      _players['trade_close'] = AudioPlayer();

      _isInitialized = true;
      debugPrint('=== AUDIO SERVICE V2: Initialized ===');
    }
  }

  // Get or create a player for a specific sound
  static AudioPlayer _getPlayer(String soundType) {
    if (!_players.containsKey(soundType)) {
      _players[soundType] = AudioPlayer();
    }
    return _players[soundType]!;
  }

  // Play no money sound
  static Future<void> playNoMoneySound() async {
    await _playSound('no_money', 'audio/no_money.wav');
  }

  // Play alert sound
  static Future<void> playAlertSound() async {
    await _playSound('alert', 'audio/alert_sound.mp3');
  }

  // Play success sound
  static Future<void> playSuccessSound() async {
    await _playSound('success', 'audio/success.mp3');
  }

  // Play trade close sound
  static Future<void> playTradeCloseSound() async {
    await _playSound('trade_close', 'audio/tradeclose.wav');
  }

  // Generic sound playing method
  static Future<void> _playSound(String soundType, String assetPath) async {
    try {
      debugPrint('=== AUDIO SERVICE V2: Playing $soundType sound ===');

      await initialize();

      final player = _getPlayer(soundType);

      // Stop any currently playing audio on this player
      await player.stop();

      // Set volume to 1.0 (full volume)
      await player.setVolume(1.0);

      // Play the sound
      await player.play(AssetSource(assetPath));
      debugPrint('Successfully played $soundType sound!');
    } catch (e) {
      debugPrint('Error playing $soundType sound: $e');

      // Try fallback paths
      await _tryFallbackPaths(soundType, assetPath);
    }
  }

  // Try different fallback paths
  static Future<void> _tryFallbackPaths(
    String soundType,
    String originalPath,
  ) async {
    final player = _getPlayer(soundType);

    // Try different path variations
    final fallbackPaths = [
      originalPath.replaceFirst('audio/', ''),
      'android/app/src/main/res/raw/${originalPath.split('/').last}',
    ];

    for (String path in fallbackPaths) {
      try {
        debugPrint('Trying fallback path: $path');
        await player.play(AssetSource(path));
        debugPrint('Successfully played $soundType sound from fallback: $path');
        return;
      } catch (e) {
        debugPrint('Fallback path failed: $path - $e');
      }
    }

    debugPrint('All fallback paths failed for $soundType sound');
  }

  // Test all sounds
  static Future<void> testAllSounds() async {
    debugPrint('=== AUDIO SERVICE V2: Testing all sounds ===');

    await playNoMoneySound();
    await Future.delayed(Duration(seconds: 1));

    await playAlertSound();
    await Future.delayed(Duration(seconds: 1));

    await playSuccessSound();
    await Future.delayed(Duration(seconds: 1));

    await playTradeCloseSound();
    await Future.delayed(Duration(seconds: 1));

    debugPrint('=== AUDIO SERVICE V2: All tests completed ===');
  }

  // Dispose all players
  static Future<void> dispose() async {
    for (String key in _players.keys) {
      try {
        await _players[key]?.dispose();
      } catch (e) {
        debugPrint('Error disposing player $key: $e');
      }
    }
    _players.clear();
    _isInitialized = false;
    debugPrint('=== AUDIO SERVICE V2: All players disposed ===');
  }

  // Dispose specific player
  static Future<void> disposePlayer(String soundType) async {
    if (_players.containsKey(soundType)) {
      try {
        await _players[soundType]?.dispose();
        _players.remove(soundType);
        debugPrint('=== AUDIO SERVICE V2: Disposed player for $soundType ===');
      } catch (e) {
        debugPrint('Error disposing player $soundType: $e');
      }
    }
  }
}
