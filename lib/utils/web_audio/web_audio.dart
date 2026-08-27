import 'web_audio_stub.dart'
    if (dart.library.html) 'web_audio_html.dart';

class WebAudioHelper {
  static void play() => playWebAlarmSound();
  static void stop() => stopWebAlarmSound();
}
