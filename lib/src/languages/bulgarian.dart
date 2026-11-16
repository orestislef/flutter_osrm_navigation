import '../settings.dart';
import '../strings.dart';

/// Bulgarian.
class BulgarianNavigationStrings extends NavigationStrings {
  /// Creates Bulgarian strings.
  const BulgarianNavigationStrings();

  @override
  String get speechLanguage => 'bg-BG';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
        'sharp right' => 'рязко надясно',
        'right' => 'надясно',
        'slight right' => 'леко надясно',
        'straight' => 'направо',
        'slight left' => 'леко наляво',
        'left' => 'наляво',
        'sharp left' => 'рязко наляво',
        'uturn' => 'обратно',
        _ => modifier,
      };

  static const _cardinals = [
    'север',
    'североизток',
    'изток',
    'югоизток',
    'юг',
    'югозапад',
    'запад',
    'северозапад',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) =>
      cardinal == null ? 'Тръгнете' : 'Тръгнете на $cardinal';

  @override
  String turn(String direction) => 'Завийте $direction';

  @override
  String keep(String direction) => 'Дръжте $direction';

  @override
  String get keepStraight => 'Продължете направо';

  @override
  String get continueStraight => 'Продължете';

  @override
  String merge(String? direction) =>
      direction == null ? 'Влейте се в движението' : 'Влейте се $direction';

  @override
  String get uturn => 'Направете обратен завой';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Влезте в кръговото кръстовище'
      : 'На кръговото кръстовище излезте на $ordinalExit';

  @override
  String get exitRoundabout => 'Излезте от кръговото кръстовище';

  // "изход 2" reads right without the gender of an ordinal.
  @override
  String ordinal(int n) => 'изход $n';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Пристигане в крайната точка',
        ArrivalType.stop => 'Пристигане на спирката',
        ArrivalType.pickup => 'Пристигане на мястото за качване',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction по $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction по $street';

  @override
  String inDistance(String distance, String instruction) =>
      'След $distance ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first, след това ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Навигация до $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'пристигате в крайната точка',
        ArrivalType.stop => 'пристигате на спирката',
        ArrivalType.pickup => 'пристигате на мястото за качване',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Пристигнахте в крайната точка',
        ArrivalType.stop => 'Пристигнахте на спирката',
        ArrivalType.pickup => 'Пристигнахте на мястото за качване',
      };

  @override
  String get recalculatingSpoken => 'Преизчисляване на маршрута';

  @override
  String get voiceOn => 'Гласовите указания са включени';

  @override
  String metersSpoken(int meters) => '$meters метра';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 километър' : '$kilometers километра';

  @override
  String feetSpoken(int feet) => '$feet фута';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 миля' : '$miles мили';

  @override
  String metersShort(int meters) => '$meters м';

  @override
  String kilometersShort(String kilometers) => '$kilometers км';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes мин' : '$hours ч $minutes мин';

  @override
  String speedUnit(DistanceUnits units) =>
      units == DistanceUnits.imperial ? 'mph' : 'км/ч';

  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      NavigationStrings.clock24(time);

  @override
  String get recalculating => 'Преизчисляване…';

  @override
  String get offRoute => 'Извън маршрута. Нов маршрут идва след малко.';

  @override
  String get gpsLost => 'Търсене на GPS…';

  @override
  String get gpsWeak => 'Слаб GPS сигнал';

  @override
  String get thenLabel => 'След това';

  @override
  String arrivalTime(String time) => 'пристигане $time';

  @override
  String get voiceTap => 'Докоснете за глас';

  @override
  String get voiceTapHint =>
      'Браузърът говори само след докосване. Докоснете тук, за да включите гласовите указания.';

  @override
  String get voiceUnavailable => 'Няма гласови указания на това устройство';

  @override
  String get mute => 'Изключи гласа';

  @override
  String get unmute => 'Включи гласа';

  @override
  String get recenter => 'Центрирай';
}
