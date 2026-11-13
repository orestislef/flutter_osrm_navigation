import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_unlock.dart';

/// Whether the voice can speak.
enum VoiceState {
  /// It speaks.
  ready,

  /// It waits for a tap. Browsers only speak after the page had one.
  needsTap,

  /// No voice: none on the device, none for the language, or no speech on
  /// this platform.
  unavailable,
}

/// What speaks the directions.
///
/// [TtsNavigationVoice] is the device's text to speech. Implement this to
/// route prompts somewhere else (your own audio, a car head unit, a log).
abstract class NavigationVoice {
  /// Whether the voice can speak right now.
  VoiceState get state;

  /// Called when [state] changes.
  set onStateChanged(VoidCallback? callback);

  /// Gets the voice going. Safe to call more than once.
  Future<void> init();

  /// Gets the voice for [language] ("en-US", "el-GR") ready and finds out
  /// whether the device has one.
  Future<void> prepare(String language);

  /// Says [text] in [language], cutting off anything still being said.
  void say(String text, String language);

  /// Stops speaking.
  void stop();
}

/// A voice that says nothing. Handy in tests and for silent navigation.
class SilentNavigationVoice implements NavigationVoice {
  /// Creates a silent voice. [said] collects what it was asked to say.
  SilentNavigationVoice();

  /// Everything it was asked to say, in order.
  final List<String> said = [];

  @override
  VoiceState get state => VoiceState.ready;

  @override
  set onStateChanged(VoidCallback? callback) {}

  @override
  Future<void> init() async {}

  @override
  Future<void> prepare(String language) async {}

  @override
  void say(String text, String language) => said.add(text);

  @override
  void stop() {}
}

/// The device's text to speech, through flutter_tts.
///
/// On iOS it speaks over music (which ducks) and with the ringer off, and
/// keeps speaking while the app is in the background as long as the app has
/// the `audio` background mode. On Android it uses the navigation audio
/// stream and ducks other audio while it talks. In a browser it waits for a
/// first tap anywhere, and it reports a missing voice for the language
/// rather than reading Greek with an English voice.
class TtsNavigationVoice implements NavigationVoice {
  /// Creates the voice.
  ///
  /// [speechRate] defaults to a normal pace on each platform (0.5 on
  /// phones, 1.0 in browsers, the two plugins count differently).
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

  VoiceState get _working => _hasVoice == false
      ? VoiceState.unavailable
      : (speechNeedsGesture() ? VoiceState.needsTap : VoiceState.ready);

  void _unlocked() {
    if (_ready) _set(_working);
  }

  @override
  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb && !speechSupported()) return;
    final platform = defaultTargetPlatform;
    // No flutter_tts on Linux, and it is untested on Windows.
    if (!kIsWeb &&
        (platform == TargetPlatform.linux ||
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.fuchsia)) {
      return;
    }
    try {
      final tts = FlutterTts();
      _tts = tts;
      await tts.setSpeechRate(speechRate ?? (kIsWeb ? 1.0 : 0.5));
      await tts.setVolume(volume);
      await tts.setPitch(pitch);
      if (!kIsWeb && platform == TargetPlatform.iOS) {
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
      } else if (!kIsWeb && platform == TargetPlatform.android) {
        await tts.setAudioAttributesForNavigation();
      }
      tts.setErrorHandler((dynamic message) {
        if (kIsWeb && '$message'.contains('not-allowed')) {
          _set(VoiceState.needsTap);
          speechRefused(_unlocked);
        }
      });
      _ready = true;
      _set(_working);
      if (kIsWeb) armSpeechUnlock(_unlocked);
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
    final short = language.split('-').first;
    bool? has;
    if (kIsWeb) {
      // Null while the browser has not listed its voices yet. Asked again
      // with the next prompt.
      has = speechHasVoice(short);
    } else {
      try {
        final answer = await _tts?.isLanguageAvailable(language);
        if (answer == true || answer == 1) has = true;
        if (answer == false || answer == 0) has = false;
      } catch (_) {}
    }
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
