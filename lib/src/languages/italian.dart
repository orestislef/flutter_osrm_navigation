import '../strings.dart';

/// Italian.
class ItalianNavigationStrings extends NavigationStrings {
  /// Creates Italian strings.
  const ItalianNavigationStrings();

  @override
  String get speechLanguage => 'it-IT';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
    'sharp right' => 'nettamente a destra',
    'right' => 'a destra',
    'slight right' => 'leggermente a destra',
    'straight' => 'dritto',
    'slight left' => 'leggermente a sinistra',
    'left' => 'a sinistra',
    'sharp left' => 'nettamente a sinistra',
    'uturn' => 'inversione a U',
    _ => modifier,
  };

  static const _cardinals = [
    'nord',
    'nord-est',
    'est',
    'sud-est',
    'sud',
    'sud-ovest',
    'ovest',
    'nord-ovest',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) =>
      cardinal == null ? 'Parti' : 'Procedi verso $cardinal';

  @override
  String turn(String direction) => 'Svolta $direction';

  @override
  String keep(String direction) => 'Resta $direction';

  @override
  String get keepStraight => 'Prosegui dritto';

  @override
  String get continueStraight => 'Prosegui';

  @override
  String merge(String? direction) =>
      direction == null ? 'Immettiti' : 'Immettiti $direction';

  @override
  String get uturn => 'Fai inversione a U';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Entra nella rotatoria'
      : 'Alla rotatoria, prendi la $ordinalExit uscita';

  @override
  String get exitRoundabout => 'Esci dalla rotatoria';

  @override
  String ordinal(int n) => '$nª';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
    ArrivalType.destination => 'Arrivo a destinazione',
    ArrivalType.stop => 'Arrivo alla fermata',
    ArrivalType.pickup => 'Arrivo al punto di ritiro',
  };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction su $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction in $street';

  @override
  String inDistance(String distance, String instruction) =>
      'Tra $distance, ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first, poi ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Navigazione verso $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
    ArrivalType.destination => 'arrivi a destinazione',
    ArrivalType.stop => 'arrivi alla fermata',
    ArrivalType.pickup => 'arrivi al punto di ritiro',
  };

  @override
  String arrived(ArrivalType type) => switch (type) {
    ArrivalType.destination => 'Sei arrivato a destinazione',
    ArrivalType.stop => 'Sei arrivato alla fermata',
    ArrivalType.pickup => 'Sei arrivato al punto di ritiro',
  };

  @override
  String get recalculatingSpoken => 'Ricalcolo del percorso';

  @override
  String get voiceOn => 'Le indicazioni vocali sono attive';

  @override
  String metersSpoken(int meters) => '$meters metri';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 chilometro' : '$kilometers chilometri';

  @override
  String feetSpoken(int feet) => '$feet piedi';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 miglio' : '$miles miglia';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes min' : '$hours h $minutes min';

  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      NavigationStrings.clock24(time);

  @override
  String get recalculating => 'Ricalcolo…';

  @override
  String get offRoute => 'Fuori percorso. Un nuovo percorso sta arrivando.';

  @override
  String get gpsLost => 'Ricerca GPS…';

  @override
  String get gpsWeak => 'Segnale GPS debole';

  @override
  String get thenLabel => 'Poi';

  @override
  String arrivalTime(String time) => 'arrivo $time';

  @override
  String get voiceTap => 'Tocca per la voce';

  @override
  String get voiceTapHint =>
      'Il browser parla solo dopo un tocco. Tocca qui per attivare le indicazioni vocali.';

  @override
  String get voiceUnavailable =>
      'Nessuna indicazione vocale su questo dispositivo';

  @override
  String get mute => 'Disattiva voce';

  @override
  String get unmute => 'Attiva voce';

  @override
  String get recenter => 'Ricentra';
}
