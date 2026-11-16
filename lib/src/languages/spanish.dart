import '../strings.dart';

/// Spanish.
class SpanishNavigationStrings extends NavigationStrings {
  /// Creates Spanish strings.
  const SpanishNavigationStrings();

  @override
  String get speechLanguage => 'es-ES';

  @override
  String get decimalSeparator => ',';

  @override
  String direction(String modifier) => switch (modifier) {
        'sharp right' => 'bruscamente a la derecha',
        'right' => 'a la derecha',
        'slight right' => 'ligeramente a la derecha',
        'straight' => 'recto',
        'slight left' => 'ligeramente a la izquierda',
        'left' => 'a la izquierda',
        'sharp left' => 'bruscamente a la izquierda',
        'uturn' => 'cambio de sentido',
        _ => modifier,
      };

  static const _cardinals = [
    'norte',
    'noreste',
    'este',
    'sureste',
    'sur',
    'suroeste',
    'oeste',
    'noroeste',
  ];

  @override
  String cardinal(int index) => _cardinals[index % 8];

  @override
  String head(String? cardinal) =>
      cardinal == null ? 'Sal' : 'Dirígete al $cardinal';

  @override
  String turn(String direction) => 'Gira $direction';

  @override
  String keep(String direction) => 'Mantente $direction';

  @override
  String get keepStraight => 'Sigue recto';

  @override
  String get continueStraight => 'Continúa';

  @override
  String merge(String? direction) =>
      direction == null ? 'Incorpórate' : 'Incorpórate $direction';

  @override
  String get uturn => 'Cambia de sentido';

  @override
  String roundabout(String? ordinalExit) => ordinalExit == null
      ? 'Entra en la rotonda'
      : 'En la rotonda, toma la $ordinalExit salida';

  @override
  String get exitRoundabout => 'Sal de la rotonda';

  @override
  String ordinal(int n) => '$n.ª';

  @override
  String arriveAt(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Llegada al destino',
        ArrivalType.stop => 'Llegada a la parada',
        ArrivalType.pickup => 'Llegada al punto de recogida',
      };

  @override
  String onStreet(String instruction, String street) =>
      '$instruction por $street';

  @override
  String ontoStreet(String instruction, String street) =>
      '$instruction hacia $street';

  @override
  String inDistance(String distance, String instruction) =>
      'En $distance, ${NavigationStrings.lowerFirst(instruction)}';

  @override
  String then(String first, String second) =>
      '$first y luego ${NavigationStrings.lowerFirst(second)}';

  @override
  String navigatingTo(String place) => 'Navegando a $place';

  @override
  String arriving(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'llegarás al destino',
        ArrivalType.stop => 'llegarás a la parada',
        ArrivalType.pickup => 'llegarás al punto de recogida',
      };

  @override
  String arrived(ArrivalType type) => switch (type) {
        ArrivalType.destination => 'Has llegado a tu destino',
        ArrivalType.stop => 'Has llegado a la parada',
        ArrivalType.pickup => 'Has llegado al punto de recogida',
      };

  @override
  String get recalculatingSpoken => 'Recalculando la ruta';

  @override
  String get voiceOn => 'Las indicaciones por voz están activadas';

  @override
  String metersSpoken(int meters) => '$meters metros';

  @override
  String kilometersSpoken(String kilometers, {required bool one}) =>
      one ? '1 kilómetro' : '$kilometers kilómetros';

  @override
  String feetSpoken(int feet) => '$feet pies';

  @override
  String milesSpoken(String miles, {required bool one}) =>
      one ? '1 milla' : '$miles millas';

  @override
  String duration(int hours, int minutes) =>
      hours == 0 ? '$minutes min' : '$hours h $minutes min';

  @override
  String clockTime(DateTime time, {required bool use24h}) =>
      NavigationStrings.clock24(time);

  @override
  String get recalculating => 'Recalculando…';

  @override
  String get offRoute => 'Fuera de la ruta. Llega una nueva ruta.';

  @override
  String get gpsLost => 'Buscando GPS…';

  @override
  String get gpsWeak => 'Señal GPS débil';

  @override
  String get thenLabel => 'Después';

  @override
  String arrivalTime(String time) => 'llegada $time';

  @override
  String get voiceTap => 'Toca para la voz';

  @override
  String get voiceTapHint =>
      'El navegador solo habla después de un toque. Toca aquí para activar las indicaciones por voz.';

  @override
  String get voiceUnavailable =>
      'No hay indicaciones por voz en este dispositivo';

  @override
  String get mute => 'Silenciar voz';

  @override
  String get unmute => 'Activar voz';

  @override
  String get recenter => 'Centrar';
}
