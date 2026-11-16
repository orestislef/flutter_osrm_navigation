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
