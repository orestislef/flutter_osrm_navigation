import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'speech_unlock_web.dart';
import 'voice_base.dart';

/// The device's text to speech: flutter_tts on phones and desktops, the
/// browser's own speech on the web.
///
/// In a browser it waits for a first tap anywhere (browsers only speak
/// after one), and it reports a missing voice for the language rather than
/// reading Greek with an English voice.
class TtsNavigationVoice implements NavigationVoice {
  /// Creates the voice.
  ///
  /// [speechRate] defaults to a normal pace on each platform (0.5 on
  /// phones and desktops, 1.0 in browsers, the two count differently).
  /// [duckOthers] lowers music while a prompt plays, where the platform
  /// allows it.
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

  JSObject? get _synth => globalContext['speechSynthesis'] as JSObject?;

  @override
  Future<void> init() async {
    if (_ready || !speechSupported()) return;
    _ready = true;
    _set(_working);
    armSpeechUnlock(_unlocked);
  }

  @override
  Future<void> prepare(String language) async {
    if (!_ready) return;
    if (language != _language) {
      _language = language;
      _hasVoice = null;
    }
    if (_hasVoice != null) return;
    // Null while the browser has not listed its voices yet. Asked again
    // with the next prompt.
    _hasVoice = speechHasVoice(language.split('-').first);
    _set(_working);
  }

  @override
  void say(String text, String language) {
    if (!_ready) return;
    prepare(language);
    if (_state != VoiceState.ready) return;
    try {
      final synth = _synth;
      if (synth == null) return;
      synth.callMethod('cancel'.toJS);
      final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
      final utterance = ctor.callAsConstructor<JSObject>(text.toJS);
      utterance['lang'] = language.toJS;
      utterance['rate'] = (speechRate ?? 1.0).toJS;
      utterance['volume'] = volume.toJS;
      utterance['pitch'] = pitch.toJS;
      utterance['onerror'] = ((JSObject event) {
        final error = event['error'];
        if (error.isA<JSString>() &&
            (error as JSString).toDart == 'not-allowed') {
          _set(VoiceState.needsTap);
          speechRefused(_unlocked);
        }
      }).toJS;
      synth.callMethod('speak'.toJS, utterance);
    } catch (e) {
      if (kDebugMode) debugPrint('flutter_osrm_navigation: speak failed ($e)');
    }
  }

  @override
  void stop() {
    try {
      _synth?.callMethod('cancel'.toJS);
    } catch (_) {}
  }
}
