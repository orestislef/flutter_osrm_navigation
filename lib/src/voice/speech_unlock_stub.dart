// Phones and desktops speak without a tap first. See speech_unlock_web.dart
// for the browser side.

/// Whether the platform has speech at all.
bool speechSupported() => true;

/// Whether the voice still waits for a tap.
bool speechNeedsGesture() => false;

/// Unlocks the voice on the next tap, then calls [onUnlocked].
void armSpeechUnlock(void Function() onUnlocked) {}

/// The platform refused to speak: wait for a tap again.
void speechRefused(void Function() onUnlocked) {}

/// Whether there is a voice for [language], null when unknown.
bool? speechHasVoice(String language) => null;
