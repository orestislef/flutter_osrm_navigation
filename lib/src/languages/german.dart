import '../strings.dart';

/// German.
class GermanNavigationStrings extends NavigationStrings {
  /// Creates German strings.
  const GermanNavigationStrings();

  @override
  String get speechLanguage => 'de-DE';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
        'sharp right' => 'scharf rechts',
        'right' => 'rechts',
        'slight right' => 'leicht rechts',
        'straight' => 'geradeaus',
        'slight left' => 'leicht links',
        'left' => 'links',
        'sharp left' => 'scharf links',
        'uturn' => 'wenden',
        _ => modifier,
      };

  static const _cardinals = [
    'Norden',
    'Nordosten',
    'Osten',
    'Südosten',
    'Süden',
    'Südwesten',
    'Westen',
    'Nordwesten',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  String head(String? cardinal) =>
      cardinal == null ? 'Losfahren' : 'Richtung $cardinal fahren';

  @override
  String turn(String direction) => '${_cap(direction)} abbiegen';

  @override
  String keep(String direction) => '${_cap(direction)} halten';

  @override
  String get keepStraight => 'Geradeaus weiterfahren';

  @override
  String get continueStraight => 'Weiterfahren';

  @override
  String merge(String? direction) =>
      direction == null ? 'Einfädeln' : '${_cap(direction)} einfädeln';

  @override
  String get uturn => 'Wenden';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'In den Kreisverkehr fahren'
      : 'Im Kreisverkehr die $ordinalExit Ausfahrt nehmen';

  @override
  String get exitRoundabout => 'Kreisverkehr verlassen';

  @override
  String ordinal(int n) => '$n.';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Ziel erreichen',
        ArrivalType.stop => 'Zwischenstopp erreichen',
        ArrivalType.pickup => 'Abholort erreichen',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction auf $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction auf $street';

  @override
  String inDistance(String distance, String instruction) =>
      'In $distance ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first, dann ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Navigation nach $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'erreichen Sie Ihr Ziel',
        ArrivalType.stop => 'erreichen Sie den Zwischenstopp',
        ArrivalType.pickup => 'erreichen Sie den Abholort',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Sie haben Ihr Ziel erreicht',
        ArrivalType.stop => 'Sie haben den Zwischenstopp erreicht',
        ArrivalType.pickup => 'Sie haben den Abholort erreicht',
      };

  @override
  String get recalculatingSpoken => 'Route wird neu berechnet';

  @override
  String get voiceOn => 'Sprachansagen sind an';

  // Dative after "In": "In 200 Metern".
  @override
  String metersSpoken(int meters) => '$meters Metern';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 Kilometer' : '$kilometers Kilometern';

  @override
  String feetSpoken(int feet) => '$feet Fuß';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 Meile' : '$miles Meilen';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes Min.' : '$hours Std. $minutes Min.';

  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      NavigationStrings.clock24(time);

  @override
  String get recalculating => 'Route wird berechnet…';

  @override
  String get offRoute => 'Abseits der Route. Eine neue Route kommt gleich.';

  @override
  String get gpsLost => 'GPS wird gesucht…';

  @override
  String get gpsWeak => 'Schwaches GPS-Signal';

  @override
  String get thenLabel => 'Dann';

  @override
  String arrivalTime(String time) => 'Ankunft $time';

  @override
  String get voiceTap => 'Tippen für Sprache';

  @override
  String get voiceTapHint =>
      'Der Browser spricht erst nach einem Tippen. Hier tippen, um die Sprachansagen einzuschalten.';

  @override
  String get voiceUnavailable => 'Keine Sprachansagen auf diesem Gerät';

  @override
  String get mute => 'Ton aus';

  @override
  String get unmute => 'Ton an';

  @override
  String get recenter => 'Zentrieren';
}
