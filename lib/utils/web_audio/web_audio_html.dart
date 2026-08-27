// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

html.AudioElement? _audioElement;

void playWebAlarmSound() {
  try {
    if (_audioElement == null) {
      // In Flutter web, assets are resolved relative to the web root
      // They are located at assets/assets/audio/vibration_sound.mp3
      _audioElement = html.AudioElement('assets/assets/audio/vibration_sound.mp3');
      _audioElement!.loop = true;
    }
    _audioElement!.currentTime = 0;
    _audioElement!.play();
  } catch (e) {
    debugPrint('Error playing web alarm sound: $e');
  }
}

void stopWebAlarmSound() {
  try {
    if (_audioElement != null) {
      _audioElement!.pause();
      _audioElement!.currentTime = 0;
    }
  } catch (e) {
    debugPrint('Error stopping web alarm sound: $e');
  }
}
