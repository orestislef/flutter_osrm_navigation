import '../strings.dart';

/// French.
class FrenchNavigationStrings extends NavigationStrings {
  /// Creates French strings.
  const FrenchNavigationStrings();

  @override
  String get speechLanguage => 'fr-FR';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
        'sharp right' => 'franchement à droite',
        'right' => 'à droite',
        'slight right' => 'légèrement à droite',
        'straight' => 'tout droit',
        'slight left' => 'légèrement à gauche',
        'left' => 'à gauche',
        'sharp left' => 'franchement à gauche',
        'uturn' => 'demi-tour',
        _ => modifier,
      };

  static const _cardinals = [
    'nord',
    'nord-est',
    'est',
    'sud-est',
    'sud',
    'sud-ouest',
    'ouest',
    'nord-ouest',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) {
    if (cardinal == null) return 'Partez';
    // "vers l'est", "vers le nord".
    final vowel = 'aeiouy'.contains(cardinal[0]);
    return vowel ? "Partez vers l'$cardinal" : 'Partez vers le $cardinal';
  }

  @override
  String turn(String direction) => 'Tournez $direction';

  @override
  String keep(String direction) => 'Restez $direction';

  @override
  String get keepStraight => 'Continuez tout droit';

  @override
  String get continueStraight => 'Continuez';

  @override
  String merge(String? direction) =>
      direction == null ? 'Insérez-vous' : 'Insérez-vous $direction';

  @override
  String get uturn => 'Faites demi-tour';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Prenez le rond-point'
      : 'Au rond-point, prenez la $ordinalExit sortie';

  @override
  String get exitRoundabout => 'Sortez du rond-point';

  @override
  String ordinal(int n) => n == 1 ? '1re' : '${n}e';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Arrivée à destination',
        ArrivalType.stop => "Arrivée à l'arrêt",
        ArrivalType.pickup => 'Arrivée au point de prise en charge',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction sur $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction sur $street';

  @override
  String inDistance(String distance, String instruction) =>
      'Dans $distance, ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first, puis ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Navigation vers $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'vous arrivez à destination',
        ArrivalType.stop => "vous arrivez à l'arrêt",
        ArrivalType.pickup => 'vous arrivez au point de prise en charge',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Vous êtes arrivé à destination',
        ArrivalType.stop => "Vous êtes arrivé à l'arrêt",
        ArrivalType.pickup => 'Vous êtes arrivé au point de prise en charge',
      };

  @override
  String get recalculatingSpoken => "Calcul d'un nouvel itinéraire";

  @override
  String get voiceOn => 'Le guidage vocal est activé';

  @override
  String metersSpoken(int meters) => '$meters mètres';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 kilomètre' : '$kilometers kilomètres';

  @override
  String feetSpoken(int feet) => '$feet pieds';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 mile' : '$miles miles';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes min' : '$hours h $minutes min';

  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      NavigationStrings.clock24(time);

  @override
  String get recalculating => 'Recalcul…';

  @override
  String get offRoute => 'Hors itinéraire. Un nouvel itinéraire arrive.';

  @override
  String get gpsLost => 'Recherche du GPS…';

  @override
  String get gpsWeak => 'Signal GPS faible';

  @override
  String get thenLabel => 'Puis';

  @override
  String arrivalTime(String time) => 'arrivée $time';

  @override
  String get voiceTap => 'Touchez pour la voix';

  @override
  String get voiceTapHint =>
      "Le navigateur ne parle qu'après un appui. Touchez ici pour activer le guidage vocal.";

  @override
  String get voiceUnavailable => 'Pas de guidage vocal sur cet appareil';

  @override
  String get mute => 'Couper la voix';

  @override
  String get unmute => 'Activer la voix';

  @override
  String get recenter => 'Recentrer';
}
