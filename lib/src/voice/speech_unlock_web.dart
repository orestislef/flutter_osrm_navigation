import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Browsers (Safari on iOS above all, Chrome too) only speak after the page
// had a tap: the first speech has to start inside a user gesture, then the
// page may speak freely. A tap anywhere in the app, seen by the page itself
// before Flutter handles it, speaks a silent word and so unlocks the voice
// for the directions that come later.

bool _unlocked = false;
bool _armed = false;
JSFunction? _handler;

const _gestures = ['touchend', 'pointerup', 'click', 'keydown'];

/// Whether the browser has speech at all.
bool speechSupported() =>
    globalContext.has('speechSynthesis') &&
    globalContext.has('SpeechSynthesisUtterance');

/// Whether the voice still waits for a tap.
bool speechNeedsGesture() => !_unlocked;

/// Speaks a silent word on the next tap anywhere, then calls [onUnlocked].
void armSpeechUnlock(void Function() onUnlocked) {
  if (_unlocked || _armed || !speechSupported()) return;
  _armed = true;
  _handler = ((JSAny? _) {
    _disarm();
    try {
      final synth = globalContext['speechSynthesis'] as JSObject;
      final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
      final word = ctor.callAsConstructor<JSObject>(' '.toJS);
      word['volume'] = 0.toJS;
      synth.callMethod('speak'.toJS, word);
      // Chrome can leave the queue paused after the page was hidden.
      synth.callMethod('resume'.toJS);
      _unlocked = true;
    } catch (_) {
      _unlocked = false;
    }
    onUnlocked();
  }).toJS;
  for (final type in _gestures) {
    globalContext.callMethod(
      'addEventListener'.toJS,
      type.toJS,
      _handler,
      true.toJS,
    );
  }
}

void _disarm() {
  final handler = _handler;
  _armed = false;
  _handler = null;
  if (handler == null) return;
  for (final type in _gestures) {
    globalContext.callMethod(
      'removeEventListener'.toJS,
      type.toJS,
      handler,
      true.toJS,
    );
  }
}

/// The browser refused to speak (not-allowed): wait for a tap again.
void speechRefused(void Function() onUnlocked) {
  _unlocked = false;
  armSpeechUnlock(onUnlocked);
}

/// Whether the browser has a voice for [language] ("el", "en"), null while
/// it has not listed its voices yet.
bool? speechHasVoice(String language) {
  try {
    final synth = globalContext['speechSynthesis'] as JSObject?;
    final voices =
        synth?.callMethod<JSArray<JSObject>>('getVoices'.toJS).toDart ??
        const [];
    if (voices.isEmpty) return null;
    final prefix = language.toLowerCase();
    return voices.any(
      (v) => ((v['lang'] as JSString?)?.toDart ?? '')
          .toLowerCase()
          .replaceAll('_', '-')
          .startsWith(prefix),
    );
  } catch (_) {
    return null;
  }
}
