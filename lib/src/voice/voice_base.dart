import 'package:flutter/foundation.dart';

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

/// Why the voice cannot speak, or may not speak well, so the app can tell
/// the user what to do.
enum VoiceProblem {
  /// Nothing wrong.
  none,

  /// No text to speech engine on the device, or it would not start.
  /// Android: the user needs a TTS app (Google's "Speech Services").
  noEngine,

  /// The engine has no voice for the language. The user has to add one in
  /// the system's text to speech settings.
  languageMissing,

  /// The voice is there but its data is not downloaded (Android). It may
  /// only speak while online, and the user can download it in the text to
  /// speech settings. The voice still speaks.
  notDownloaded,

  /// No speech on this platform or browser.
  unsupportedPlatform,

  /// The voice does not say (a voice of your own).
  unknown,
}

/// A voice that can say why it cannot speak, and look again (after the user
/// installed a voice and came back to the app).
abstract class DiagnosableVoice {
  /// What is wrong, [VoiceProblem.none] when nothing is.
  VoiceProblem get problem;

  /// Looks again at the engine and the voice for [language].
  Future<void> recheck(String language);
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
