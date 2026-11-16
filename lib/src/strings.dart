import 'route.dart';
import 'settings.dart';

/// What the user is driving to. It changes how arrival is shown and said.
enum ArrivalType {
  /// The end of the trip.
  destination,

  /// A stop on the way. Every intermediate waypoint of a route is a stop.
  stop,

  /// Picking someone or something up.
  pickup,
}

/// Every word navigation shows or says.
///
/// English ([EnglishNavigationStrings]) and Greek
/// ([GreekNavigationStrings]) come built in. For another language extend
/// one of them and override what you need, or extend this class and fill in
/// everything. [instruction] builds the turn text from the small pieces, so
/// most languages only need the pieces.
abstract class NavigationStrings {
  /// Const constructor for subclasses.
  const NavigationStrings();

  /// The built in strings for [languageCode] ("en", "el", "en-US"), English
  /// when there are none for it.
  factory NavigationStrings.forLanguage(String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('el')) return const GreekNavigationStrings();
    return const EnglishNavigationStrings();
  }

  /// The language the voice speaks, as a BCP 47 tag ("en-US", "el-GR").
  String get speechLanguage;

  /// The decimal separator for numbers in text.
  String get decimalSeparator => '.';

  // Directions.

  /// The words for an OSRM modifier: `right`, `sharp left`, `straight`.
  String direction(String modifier);

  /// The words for a compass direction, [index] 0 for north going
  /// clockwise in eighths (1 is northeast, 2 east, up to 7 northwest).
  String cardinal(int index);

  // Instruction pieces.

  /// "Head", or "Head east" with a [cardinal] direction.
  String head(String? cardinal);

  /// "Turn left".
  String turn(String direction);

  /// "Keep left".
  String keep(String direction);

  /// "Keep straight".
  String get keepStraight;

  /// "Continue".
  String get continueStraight;

  /// "Merge", or "Merge left" with a [direction].
  String merge(String? direction);

  /// "Make a U-turn".
  String get uturn;

  /// "Enter the roundabout", or with an exit "Enter the roundabout, take the
  /// 2nd exit".
  String roundabout(String? ordinalExit);

  /// "Exit the roundabout".
  String get exitRoundabout;

  /// "2nd", for a roundabout exit.
  String ordinal(int n);

  /// "Arrive at the destination", the banner text for the arrival step.
  String arriveAt(ArrivalType type);

  /// "[instruction] on [street]".
  String onStreet(String instruction, String street);

  /// "[instruction] onto [street]".
  String ontoStreet(String instruction, String street);

  // Spoken.

  /// "In [distance], [instruction]".
  String inDistance(String distance, String instruction);

  /// "[first], then [second]".
  String then(String first, String second);

  /// "Navigating to [place]", said at the start when there is a name.
  String navigatingTo(String place);

  /// "you reach the destination", after "In 200 meters, ".
  String arriving(ArrivalType type);

  /// "You are at the destination".
  String arrived(ArrivalType type);

  /// Said when a new route is being asked for.
  String get recalculatingSpoken;

  /// Said when the user turns the voice on in a browser, so they hear it
  /// works.
  String get voiceOn;

  // Distances and time.

  /// "200 meters".
  String metersSpoken(int meters);

  /// "1.5 kilometers". [one] is true for exactly one.
  String kilometersSpoken(String kilometers, {required bool one});

  /// "500 feet".
  String feetSpoken(int feet);

  /// "0.3 miles". [one] is true for exactly one.
  String milesSpoken(String miles, {required bool one});

  /// "200 m".
  String metersShort(int meters) => '$meters m';

  /// "1.5 km".
  String kilometersShort(String kilometers) => '$kilometers km';

  /// "500 ft".
  String feetShort(int feet) => '$feet ft';

  /// "0.3 mi".
  String milesShort(String miles) => '$miles mi';

  /// "13 min" for under an hour, "1 h 5 min" above.
  String duration(int hours, int minutes);

  /// The unit under the speed: "km/h" or "mph".
  String speedUnit(DistanceUnits units) =>
      units == DistanceUnits.imperial ? 'mph' : 'km/h';

  /// [speedMps] in the units shown, rounded to a whole number.
  int speedValue(double speedMps, DistanceUnits units) {
    final v =
        units == DistanceUnits.imperial ? speedMps * 2.2369363 : speedMps * 3.6;
    return v.isFinite && v > 0 ? v.round() : 0;
  }

  /// A time of day, "5:14 PM" or "17:14". [use24h] is the device's 24 hour
  /// setting, for languages where both are in use.
  String clockTime(DateTime time, {required bool use24h}) {
    final m = time.minute.toString().padLeft(2, '0');
    if (use24h) return '${time.hour.toString().padLeft(2, '0')}:$m';
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    return '$h:$m ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  // Banner.

  /// Banner text while a new route is on its way.
  String get recalculating;

  /// Banner line while off the route and no new route yet.
  String get offRoute;

  /// Banner line while no GPS fix comes.
  String get gpsLost => 'Searching for GPS…';

  /// Banner line while fixes come but are too rough to use.
  String get gpsWeak => 'Weak GPS signal';

  /// Label before the maneuver that follows right after the next one.
  String get thenLabel;

  /// "arrive 14:32" in the banner footer.
  String arrivalTime(String time);

  /// Tap hint shown in a browser that will not speak before a tap.
  String get voiceTap;

  /// Tooltip with the same hint, longer.
  String get voiceTapHint;

  /// Tooltip when the device has no voice for the language.
  String get voiceUnavailable;

  /// Tooltip of the button that mutes the voice.
  String get mute;

  /// Tooltip of the button that turns the voice on.
  String get unmute;

  /// Tooltip and label of the button that follows the position again.
  String get recenter;

  // Built from the pieces above.

  /// The instruction text for [step], "Turn left onto Main Street".
  ///
  /// [arrival] is what an arrival step arrives at.
  String instruction(NavStep step,
      {ArrivalType arrival = ArrivalType.destination}) {
    final road = step.road;
    String on(String text) => road.isEmpty ? text : onStreet(text, road);
    String onto(String text) => road.isEmpty ? text : ontoStreet(text, road);
    final mod = step.modifier;
    final straight = mod == null || mod.isEmpty || mod == 'straight';
    final dir = straight ? '' : direction(mod);
    final type = step.maneuverType;

    // A U-turn has no word as a direction ("keep U-turn"), so it is always
    // said as one, whatever the maneuver.
    if (step.isUturn && !step.isArrive && !step.isRoundabout) {
      return onto(uturn);
    }
    switch (type) {
      case 'depart':
        final b = step.bearingAfter;
        return on(
            head(b == null ? null : cardinal(((b % 360) / 45).round() % 8)));
      case 'arrive':
        return arriveAt(arrival);
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        final exit = step.exit;
        return onto(
            roundabout(exit != null && exit > 0 ? ordinal(exit) : null));
      case 'exit roundabout':
      case 'exit rotary':
        return onto(exitRoundabout);
      case 'new name':
      case 'notification':
        return on(continueStraight);
      case 'continue':
        return straight ? on(continueStraight) : onto(keep(dir));
      case 'fork':
      case 'on ramp':
      case 'off ramp':
        return onto(straight ? keepStraight : keep(dir));
      case 'merge':
        return onto(merge(straight ? null : dir));
      default:
        return onto(straight ? continueStraight : turn(dir));
    }
  }

  /// [distanceM] as said by the voice, rounded the way people say it.
  ///
  /// The switch to kilometres (or miles) is made on the rounded value, so
  /// 990 m is "1 kilometer" and not "1000 meters".
  String spokenDistance(double distanceM, DistanceUnits units) {
    if (units == DistanceUnits.imperial) {
      final feet = distanceM * 3.28084;
      final rounded = feet > 300
          ? (feet / 50).round() * 50
          : _atLeast10((feet / 10).round() * 10);
      if (rounded < 1000) return feetSpoken(rounded);
      final miles = distanceM / 1609.344;
      final text = _decimal(miles, miles < 10 ? 1 : 0);
      return milesSpoken(text, one: text == '1');
    }
    final metres = distanceM > 100
        ? (distanceM / 50).round() * 50
        : _atLeast10((distanceM / 10).round() * 10);
    if (metres < 1000) return metersSpoken(metres);
    final km = distanceM / 1000;
    final text = _decimal(km, km < 10 ? 1 : 0);
    return kilometersSpoken(text, one: text == '1');
  }

  /// [distanceM] as shown on screen, "200 m", "4.3 km".
  String shortDistance(double distanceM, DistanceUnits units) {
    if (units == DistanceUnits.imperial) {
      final feet = distanceM * 3.28084;
      final rounded = feet > 300
          ? (feet / 50).round() * 50
          : (feet > 100 ? (feet / 10).round() * 10 : feet.round());
      if (rounded < 1000) return feetShort(rounded);
      final miles = distanceM / 1609.344;
      return milesShort(_decimal(miles, miles < 10 ? 1 : 0));
    }
    final rounded = distanceM > 300
        ? (distanceM / 50).round() * 50
        : (distanceM > 100 ? (distanceM / 10).round() * 10 : distanceM.round());
    if (rounded < 1000) return metersShort(rounded);
    final km = distanceM / 1000;
    return kilometersShort(_decimal(km, km < 10 ? 1 : 0));
  }

  /// [seconds] as shown on screen, at least one minute.
  String shortDuration(double seconds) {
    final total = (seconds / 60).round() < 1 ? 1 : (seconds / 60).round();
    return duration(total ~/ 60, total % 60);
  }

  static int _atLeast10(int v) => v < 10 ? 10 : v;

  /// [value] with [decimals] decimals, a trailing ".0" dropped.
  String _decimal(double value, int decimals) {
    var text = value.toStringAsFixed(decimals);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return text.replaceAll('.', decimalSeparator);
  }

  /// [text] with its first letter lower case, for the middle of a sentence.
  static String lowerFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toLowerCase() + text.substring(1);
  }
}

/// English.
class EnglishNavigationStrings extends NavigationStrings {
  /// Creates English strings.
  const EnglishNavigationStrings();

  @override
  String get speechLanguage => 'en-US';

  @override
  String direction(String modifier) => switch (modifier) {
        'uturn' => 'U-turn',
        _ => modifier,
      };

  static const _cardinals = [
    'north',
    'northeast',
    'east',
    'southeast',
    'south',
    'southwest',
    'west',
    'northwest',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) => cardinal == null ? 'Head' : 'Head $cardinal';

  @override
  String turn(String direction) => 'Turn $direction';

  @override
  String keep(String direction) => 'Keep $direction';

  @override
  String get keepStraight => 'Keep straight';

  @override
  String get continueStraight => 'Continue';

  @override
  String merge(String? direction) =>
      direction == null ? 'Merge' : 'Merge $direction';

  @override
  String get uturn => 'Make a U-turn';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Enter the roundabout'
      : 'Enter the roundabout, take the $ordinalExit exit';

  @override
  String get exitRoundabout => 'Exit the roundabout';

  @override
  String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Arrive at the destination',
        ArrivalType.stop => 'Arrive at the stop',
        ArrivalType.pickup => 'Arrive at the pickup',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction on $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction onto $street';

  @override
  String inDistance(String distance, String instruction) =>
      'In $distance, ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first, then ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Navigating to $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'you reach the destination',
        ArrivalType.stop => 'you reach the stop',
        ArrivalType.pickup => 'you reach the pickup',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'You are at the destination',
        ArrivalType.stop => 'You are at the stop',
        ArrivalType.pickup => 'You are at the pickup',
      };

  @override
  String get recalculatingSpoken => 'Recalculating the route';

  @override
  String get voiceOn => 'Voice directions are on';

  @override
  String metersSpoken(int meters) => '$meters meters';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 kilometer' : '$kilometers kilometers';

  @override
  String feetSpoken(int feet) => '$feet feet';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 mile' : '$miles miles';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes min' : '$hours h $minutes min';

  @override
  String get recalculating => 'Recalculating…';

  @override
  String get offRoute => 'Off the route. A new route is on its way.';

  @override
  String get thenLabel => 'Then';

  @override
  String arrivalTime(String time) => 'arrive $time';

  @override
  String get voiceTap => 'Tap for voice';

  @override
  String get voiceTapHint =>
      'The browser speaks only after a tap. Tap here to turn on voice directions.';

  @override
  String get voiceUnavailable => 'No voice directions on this device';

  @override
  String get mute => 'Mute voice';

  @override
  String get unmute => 'Turn voice on';

  @override
  String get recenter => 'Re-center';
}

/// Greek.
class GreekNavigationStrings extends NavigationStrings {
  /// Creates Greek strings.
  const GreekNavigationStrings();

  @override
  String get speechLanguage => 'el-GR';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
        'sharp right' => 'απότομα δεξιά',
        'right' => 'δεξιά',
        'slight right' => 'ελαφρώς δεξιά',
        'straight' => 'ευθεία',
        'slight left' => 'ελαφρώς αριστερά',
        'left' => 'αριστερά',
        'sharp left' => 'απότομα αριστερά',
        'uturn' => 'αναστροφή',
        _ => modifier,
      };

  static const _cardinals = [
    'βόρεια',
    'βορειοανατολικά',
    'ανατολικά',
    'νοτιοανατολικά',
    'νότια',
    'νοτιοδυτικά',
    'δυτικά',
    'βορειοδυτικά',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) =>
      cardinal == null ? 'Ξεκινήστε' : 'Κινηθείτε $cardinal';

  @override
  String turn(String direction) => 'Στρίψτε $direction';

  @override
  String keep(String direction) => 'Κρατηθείτε $direction';

  @override
  String get keepStraight => 'Συνεχίστε ευθεία';

  @override
  String get continueStraight => 'Συνεχίστε';

  @override
  String merge(String? direction) => direction == null
      ? 'Ενταχθείτε στην κυκλοφορία'
      : 'Ενταχθείτε $direction';

  @override
  String get uturn => 'Κάντε αναστροφή';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Μπείτε στον κυκλικό κόμβο'
      : 'Μπείτε στον κυκλικό κόμβο και βγείτε στην $ordinalExit έξοδο';

  @override
  String get exitRoundabout => 'Βγείτε από τον κυκλικό κόμβο';

  // Feminine, for "η έξοδος".
  @override
  String ordinal(int n) => '$nη';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Φτάνετε στον προορισμό',
        ArrivalType.stop => 'Φτάνετε στη στάση',
        ArrivalType.pickup => 'Φτάνετε στο σημείο παραλαβής',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction στην $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction στην $street';

  @override
  String inDistance(String distance, String instruction) =>
      'Σε $distance, ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first και μετά ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Πλοήγηση προς $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'φτάνετε στον προορισμό',
        ArrivalType.stop => 'φτάνετε στη στάση',
        ArrivalType.pickup => 'φτάνετε στο σημείο παραλαβής',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Φτάσατε στον προορισμό',
        ArrivalType.stop => 'Φτάσατε στη στάση',
        ArrivalType.pickup => 'Φτάσατε στο σημείο παραλαβής',
      };

  @override
  String get recalculatingSpoken => 'Υπολογισμός νέας διαδρομής';

  @override
  String get voiceOn => 'Οι φωνητικές οδηγίες είναι ανοιχτές';

  @override
  String metersSpoken(int meters) => '$meters μέτρα';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 χιλιόμετρο' : '$kilometers χιλιόμετρα';

  @override
  String feetSpoken(int feet) => '$feet πόδια';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 μίλι' : '$miles μίλια';

  @override
  String kilometersShort(String kilometers) => '$kilometers χλμ';

  @override
  String metersShort(int meters) => '$meters μ';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes λεπ.' : '$hours ώρ. $minutes λεπ.';

  @override
  String speedUnit(DistanceUnits units) =>
      units == DistanceUnits.imperial ? 'mph' : 'χλμ/ώ';

  // Greece reads the time on the 24 hour clock.
  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  String get recalculating => 'Επανυπολογισμός…';

  @override
  String get offRoute => 'Εκτός διαδρομής. Νέα διαδρομή σε λίγο.';

  @override
  String get gpsLost => 'Αναζήτηση σήματος GPS…';

  @override
  String get gpsWeak => 'Αδύναμο σήμα GPS';

  @override
  String get thenLabel => 'Μετά';

  @override
  String arrivalTime(String time) => 'άφιξη $time';

  @override
  String get voiceTap => 'Πατήστε για φωνή';

  @override
  String get voiceTapHint =>
      'Ο browser μιλά μόνο μετά από ένα πάτημα. Πατήστε εδώ για φωνητικές οδηγίες.';

  @override
  String get voiceUnavailable =>
      'Δεν υπάρχουν φωνητικές οδηγίες σε αυτή τη συσκευή';

  @override
  String get mute => 'Σίγαση φωνής';

  @override
  String get unmute => 'Ενεργοποίηση φωνής';

  @override
  String get recenter => 'Επανακέντρωση';
}
