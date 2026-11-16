import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_base.dart';

/// The device's text to speech: flutter_tts on phones and desktops, the
/// browser's own speech on the web.
///
/// On iOS it speaks over music (which ducks) and with the ringer off, and
/// keeps speaking while the app is in the background as long as the app has
/// the `audio` background mode. On Android it uses the navigation audio
/// stream and ducks other audio while it talks. In a browser it waits for a
/// first tap anywhere. Everywhere it reports a missing voice for the
/// language rather than reading Greek with an English voice.
class TtsNavigationVoice implements NavigationVoice {
  /// Creates the voice.
  ///
  /// [speechRate] defaults to a normal pace on each platform (0.5 on
  /// phones and desktops, 1.0 in browsers, the two count differently).
  /// [duckOthers] lowers music while a prompt plays.
  TtsNavigationVoice({
    this.speechRate,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.duckOthers = true,
  });

  /// Speed, null for the platform's normal pace.
  final double? speechRate;

  /// Volume, 0 to 1.
  final double volume;

  /// Pitch, 0.5 to 2.
  final double pitch;

  /// Lower other audio while speaking.
  final bool duckOthers;

  FlutterTts? _tts;
  bool _ready = false;
  VoiceState _state = VoiceState.unavailable;
  String? _language;
  bool? _hasVoice;
  VoidCallback? _onStateChanged;

  @override
  VoiceState get state => _state;

  @override
  set onStateChanged(VoidCallback? callback) => _onStateChanged = callback;

  void _set(VoiceState s) {
    if (s == _state) return;
    _state = s;
    _onStateChanged?.call();
  }

  VoiceState get _working =>
      _hasVoice == false ? VoiceState.unavailable : VoiceState.ready;

  @override
  Future<void> init() async {
    if (_ready) return;
    final platform = defaultTargetPlatform;
    // No flutter_tts on Linux, and it is untested on Windows.
    if ((platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.fuchsia)) {
      return;
    }
    try {
      final tts = FlutterTts();
      _tts = tts;
      await tts.setSpeechRate(speechRate ?? 0.5);
      await tts.setVolume(volume);
      await tts.setPitch(pitch);
      if (platform == TargetPlatform.iOS) {
        // Over music, with the ringer off, and on in the background.
        await tts.setSharedInstance(true);
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            if (duckOthers) IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } else if (platform == TargetPlatform.android) {
        await tts.setAudioAttributesForNavigation();
      }
      _ready = true;
      _set(_working);
    } catch (e) {
      if (kDebugMode) debugPrint('flutter_osrm_navigation: no voice ($e)');
    }
  }

  @override
  Future<void> prepare(String language) async {
    if (!_ready) return;
    if (language != _language) {
      _language = language;
      _hasVoice = null;
      try {
        await _tts?.setLanguage(language);
      } catch (_) {}
    }
    if (_hasVoice != null) return;
    bool? has;
    try {
      final answer = await _tts?.isLanguageAvailable(language);
      if (answer == true || answer == 1) has = true;
      if (answer == false || answer == 0) has = false;
    } catch (_) {}
    _hasVoice = has;
    _set(_working);
  }

  @override
  void say(String text, String language) {
    final tts = _tts;
    if (tts == null) return;
    () async {
      try {
        await tts.stop();
        await prepare(language);
        if (_state != VoiceState.ready) return;
        await tts.speak(text, focus: duckOthers);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('flutter_osrm_navigation: speak failed ($e)');
        }
      }
    }();
  }

  @override
  void stop() {
    _tts?.stop().catchError((Object _) => null);
  }
}
