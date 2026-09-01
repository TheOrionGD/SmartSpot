import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../utils/web_audio/web_audio.dart';

/// Centralized service for concurrent Real Hardware Alarm Vibration and MP3 Tune Playback.
/// 
/// Runs vibration and audio playback in parallel whenever an alarm or reminder triggers.
class AlarmAudioService {
  AlarmAudioService._();
  static final AlarmAudioService instance = AlarmAudioService._();

  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isVibrating = false;

  bool get isRinging => _isPlaying || _isVibrating;

  /// Starts the alarm: Triggers continuous hardware vibration AND concurrently plays the MP3 tune.
  Future<void> startAlarm({
    bool loop = true,
    bool enableVibration = true,
    bool enableSound = true,
  }) async {
    await stop(); // Ensure any previous session is cleaned up

    _isPlaying = true;
    _isVibrating = true;

    // 1. Real Hardware Vibration (concurrent)
    if (enableVibration && !kIsWeb) {
      _startHardwareVibration(loop: loop);
    }

    // 2. Play MP3 Tune (concurrent)
    if (enableSound) {
      _playAudioTune(loop: loop);
    }
  }

  /// Triggers real hardware motor vibration using the Vibration package.
  Future<void> _startHardwareVibration({required bool loop}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        if (loop) {
          // Continuous alarm vibration pulse pattern
          // [wait, vibrate, wait, vibrate, wait, vibrate, wait]
          await Vibration.vibrate(
            pattern: [0, 800, 300, 800, 300, 1000, 500],
            repeat: 0, // repeat from index 0 indefinitely
          );
        } else {
          // Single burst for alerts
          await Vibration.vibrate(
            pattern: [0, 600, 200, 600],
          );
        }
      }
    } catch (e) {
      debugPrint('AlarmAudioService hardware vibration error: $e');
    }
  }

  /// Plays the vibration_sound.mp3 tune concurrently on all platforms.
  Future<void> _playAudioTune({required bool loop}) async {
    if (kIsWeb) {
      try {
        WebAudioHelper.play();
      } catch (e) {
        debugPrint('Web audio playback error: $e');
      }
      return;
    }

    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      
      await _player!.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );

      // Set audio context to alarm / high volume stream
      try {
        await _player!.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioMode: AndroidAudioMode.normal,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      } catch (_) {}

      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('audio/vibration_sound.mp3'));
    } catch (e) {
      debugPrint('AlarmAudioService audio playback error: $e');
    }
  }

  /// Stops both the audio playback and hardware vibration immediately.
  Future<void> stop() async {
    _isPlaying = false;
    _isVibrating = false;

    // Stop Web Audio
    if (kIsWeb) {
      try {
        WebAudioHelper.stop();
      } catch (_) {}
    }

    // Stop Native Audio Player
    if (_player != null) {
      try {
        await _player!.stop();
      } catch (_) {}
    }

    // Cancel Hardware Vibration
    if (!kIsWeb) {
      try {
        await Vibration.cancel();
      } catch (_) {}
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
    _player = null;
  }
}
