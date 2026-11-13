import 'package:flutter_osrm_navigation/flutter_osrm_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

NavStep s(String type,
        {String? modifier,
        String name = '',
        String ref = '',
        int? exit,
        double? bearingAfter}) =>
    NavStep(
      maneuverType: type,
      modifier: modifier,
      location: const LatLng(0, 0),
      streetName: name,
      ref: ref,
      exit: exit,
      bearingAfter: bearingAfter,
    );

void main() {
  const en = EnglishNavigationStrings();
  const el = GreekNavigationStrings();

  test('picks the language from a code', () {
    expect(NavigationStrings.forLanguage('el'), isA<GreekNavigationStrings>());
    expect(
        NavigationStrings.forLanguage('el-GR'), isA<GreekNavigationStrings>());
    expect(NavigationStrings.forLanguage('en_US'),
        isA<EnglishNavigationStrings>());
    expect(
        NavigationStrings.forLanguage('fr'), isA<EnglishNavigationStrings>());
  });

  group('instructions in English', () {
    test('turns, keeps and merges', () {
      expect(en.instruction(s('turn', modifier: 'left', name: 'Main St')),
          'Turn left onto Main St');
      expect(en.instruction(s('turn', modifier: 'sharp right')),
          'Turn sharp right');
      expect(en.instruction(s('end of road', modifier: 'right', ref: 'A1')),
          'Turn right onto A1');
      expect(en.instruction(s('fork', modifier: 'slight left')),
          'Keep slight left');
      expect(
          en.instruction(s('off ramp', modifier: 'straight')), 'Keep straight');
      expect(en.instruction(s('merge')), 'Merge');
      expect(en.instruction(s('merge', modifier: 'left')), 'Merge left');
      expect(en.instruction(s('new name', name: 'Oak Ave')),
          'Continue on Oak Ave');
      expect(en.instruction(s('continue', modifier: 'right')), 'Keep right');
    });

    test('a U-turn is a U-turn whatever the maneuver says', () {
      expect(en.instruction(s('continue', modifier: 'uturn', name: 'X')),
          'Make a U-turn onto X');
      expect(en.instruction(s('turn', modifier: 'uturn')), 'Make a U-turn');
    });

    test('roundabouts with and without the exit', () {
      expect(en.instruction(s('roundabout', exit: 2, name: 'Elm')),
          'Enter the roundabout, take the 2nd exit onto Elm');
      expect(en.instruction(s('rotary')), 'Enter the roundabout');
      expect(en.instruction(s('exit roundabout', name: 'Elm')),
          'Exit the roundabout onto Elm');
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(en.ordinal),
          ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd']);
    });

    test('the departure says the compass direction', () {
      expect(en.instruction(s('depart', bearingAfter: 92, name: 'Elm')),
          'Head east on Elm');
      expect(en.instruction(s('depart', bearingAfter: 350)), 'Head north');
      expect(en.instruction(s('depart')), 'Head');
    });

    test('arrival by type', () {
      expect(en.instruction(s('arrive')), 'Arrive at the destination');
      expect(en.instruction(s('arrive'), arrival: ArrivalType.stop),
          'Arrive at the stop');
    });

    test('in distance and then read as one sentence', () {
      expect(en.inDistance('200 meters', 'Turn left onto Elm'),
          'In 200 meters, turn left onto Elm');
      expect(en.then('Turn left', 'Turn right onto Elm'),
          'Turn left, then turn right onto Elm');
    });
  });

  group('instructions in Greek', () {
    test('turns and roundabouts', () {
      expect(el.instruction(s('turn', modifier: 'left', name: 'Ερμού')),
          'Στρίψτε αριστερά στην Ερμού');
      expect(el.instruction(s('roundabout', exit: 3)),
          'Μπείτε στον κυκλικό κόμβο και βγείτε στην 3η έξοδο');
      expect(
          el.instruction(s('continue', modifier: 'uturn')), 'Κάντε αναστροφή');
      expect(el.inDistance('200 μέτρα', 'Στρίψτε δεξιά'),
          'Σε 200 μέτρα, στρίψτε δεξιά');
    });
  });

  group('distances', () {
    test('spoken metric, rounded the way people say it', () {
      String say(double m) => en.spokenDistance(m, DistanceUnits.metric);
      expect(say(4), '10 meters');
      expect(say(37), '40 meters');
      expect(say(186), '200 meters');
      expect(say(620), '600 meters');
      expect(say(1000), '1 kilometer');
      expect(say(1540), '1.5 kilometers');
      expect(say(23400), '23 kilometers');
      expect(el.spokenDistance(1540, DistanceUnits.metric), '1,5 χιλιόμετρα');
    });

    test('spoken imperial', () {
      String say(double m) => en.spokenDistance(m, DistanceUnits.imperial);
      expect(say(30), '100 feet');
      expect(say(152), '500 feet');
      expect(say(1609.344), '1 mile');
      expect(say(800), '0.5 miles');
    });

    test('short on screen', () {
      expect(en.shortDistance(85, DistanceUnits.metric), '85 m');
      expect(en.shortDistance(233, DistanceUnits.metric), '230 m');
      expect(en.shortDistance(4321, DistanceUnits.metric), '4.3 km');
      expect(el.shortDistance(4321, DistanceUnits.metric), '4,3 χλμ');
      expect(en.shortDistance(3218.7, DistanceUnits.imperial), '2 mi');
    });

    test('just under a kilometer is a kilometer, not "1000 m"', () {
      expect(en.shortDistance(999.6, DistanceUnits.metric), '1 km');
      expect(el.shortDistance(990, DistanceUnits.metric), '1 χλμ');
      expect(en.spokenDistance(990, DistanceUnits.metric), '1 kilometer');
      expect(en.shortDistance(301.8, DistanceUnits.imperial), '0.2 mi');
      expect(en.spokenDistance(301.8, DistanceUnits.imperial), '0.2 miles');
    });

    test('duration', () {
      expect(en.shortDuration(10), '1 min');
      expect(en.shortDuration(13 * 60), '13 min');
      expect(en.shortDuration(65 * 60), '1 h 5 min');
      expect(el.shortDuration(13 * 60), '13 λεπ.');
    });
  });
}
