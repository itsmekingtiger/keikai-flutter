import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/charts/charts.dart';

import '../support/harness.dart';
import 'util.dart';

void main() {
  setUpAll(loadKkFonts);

  group('KkTrace', () {
    const List<double?> wave = <double?>[0, 1, 0, -1, 0, 1, 0, -1];

    testWidgets('the scope is 96 tall under the head, with the reading at the right', (WidgetTester tester) async {
      await pumpKk(tester, const KkTrace(cjk: '主電源', en: 'main bus', value: '050.0 Hz', samples: wave));
      expect(tester.getSize(find.byType(KkCanvas)), const Size(798, 96));
      expect(tester.getSize(find.byType(KkTrace)).height, closeTo(2 + 38.7 + 96, 1.5));
      final Text reading = tester.widget<Text>(find.text('050.0 Hz'));
      expect(reading.style!.color, KkColors.standby.nominal);
      expect(find.byType(KkGlyph), findsNothing);
    });

    testWidgets('a level colours the reading and adds its icon', (WidgetTester tester) async {
      await pumpKk(tester, const KkTrace(en: 'carrier', value: '-091 dBm', level: KkLevel.caution, samples: wave));
      expect(tester.widget<Text>(find.text('-091 dBm')).style!.color, KkColors.standby.caution);
      expect(tester.widget<KkGlyph>(find.byType(KkGlyph)).level, KkLevel.caution);
    });

    testWidgets('bare, free width and fixed height', (WidgetTester tester) async {
      await pumpKk(tester, const KkTrace(frame: false, samples: wave, height: 64));
      expect(tester.getSize(find.byType(KkTrace)), const Size(800, 64));
      await pumpKk(tester, const KkRow(children: <Widget>[KkTrace(frame: false, samples: wave)]));
      expect(tester.getSize(find.byType(KkTrace)), const Size(280, 96));
      await pumpKk(
        tester,
        const KkBox(width: 300, height: 200, child: KkTrace(cjk: '主電源', en: 'main bus', samples: wave)),
      );
      expect(tester.getSize(find.byType(KkCanvas)).height, closeTo(200 - 2 - 38.7, 1));
    });

    testWidgets('flows with motion on and stands still with it off', (WidgetTester tester) async {
      await pumpKk(tester, const KkTrace(samples: wave, flowing: true), motion: true);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      }
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'a flowing trace keeps ticking');
      await pumpKk(tester, const KkTrace(samples: wave, flowing: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no motion, no ticker');
    });

    testWidgets('survives empty, flat and broken samples at any size', (WidgetTester tester) async {
      const List<List<double?>> cases = <List<double?>>[
        <double?>[],
        <double?>[3],
        <double?>[2, 2, 2],
        <double?>[null, double.nan, double.infinity],
        <double?>[1, null, 2, double.nan, 3, 1e300, -1e300],
      ];
      for (final List<double?> samples in cases) {
        for (final bool flowing in <bool>[false, true]) {
          for (final Size size in const <Size>[Size(400, 200), Size(20, 20), Size.zero]) {
            await pumpKk(
              tester,
              KkBox(
                width: size.width,
                height: size.height,
                child: KkTrace(cjk: '主電源', en: 'main bus', value: 'X', samples: samples, flowing: flowing, min: 0, max: 0),
              ),
              motion: flowing,
            );
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull, reason: '$samples flowing=$flowing at $size');
          }
        }
      }
    });
  });

  group('KkRadar', () {
    const List<KkRadarContact> contacts = <KkRadarContact>[
      KkRadarContact(id: 'T-01', bearing: 90, range: 50, level: KkLevel.nominal),
      KkRadarContact(id: 'T-02', bearing: 180, range: 100, level: KkLevel.critical),
      KkRadarContact(id: 'T-03', bearing: 0, range: 25),
    ];

    testWidgets('the scope is square up to maxSize, then fits what it is given', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 260, child: KkRadar(frame: false, contacts: contacts)));
      expect(tester.getSize(find.byType(KkRadar)), const Size(260, 260));
      await pumpKk(tester, const KkRadar(frame: false, contacts: contacts));
      expect(tester.getSize(find.byType(KkRadar)), const Size(800, 320));
      await pumpKk(tester, const KkRadar(frame: false, contacts: contacts, maxSize: 200));
      expect(tester.getSize(find.byType(KkRadar)).height, 200);
      await pumpKk(tester, const KkBox(width: 300, height: 180, child: KkRadar(frame: false, contacts: contacts)));
      expect(tester.getSize(find.byType(KkRadar)), const Size(300, 180));
      await pumpKk(tester, const KkRow(children: <Widget>[KkRadar(frame: false, contacts: contacts)]));
      expect(tester.getSize(find.byType(KkRadar)), const Size(260, 260));
    });

    testWidgets('hover and tap find contacts by bearing and range', (WidgetTester tester) async {
      final List<String?> seen = <String?>[];
      final List<String> taps = <String>[];
      // 264 square: 12 padding, 240 units across, one unit per pixel, centre at (132, 132).
      await pumpKk(
        tester,
        KkBox(
          width: 264,
          height: 264,
          child: KkRadar(
            frame: false,
            contacts: contacts,
            range: 100,
            onContactHover: (KkRadarContact? c) => seen.add(c?.id),
            onContactTap: (KkRadarContact c) => taps.add(c.id),
          ),
        ),
      );
      final Rect scope = plotRect(tester, find.byType(KkRadar));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(scope.topLeft + const Offset(182, 132));
      await tester.pump();
      await pointer.moveTo(scope.topLeft + const Offset(132, 232));
      await tester.pump();
      await pointer.moveTo(scope.topLeft + const Offset(134, 105));
      await tester.pump();
      await pointer.moveTo(scope.topLeft + const Offset(40, 40));
      await tester.pump();
      expect(seen, <String?>['T-01', 'T-02', 'T-03', null]);
      await tester.tapAt(scope.topLeft + const Offset(182, 132));
      await tester.tapAt(scope.topLeft + const Offset(40, 40));
      expect(taps, <String>['T-01']);
    });

    testWidgets('is not interactive without callbacks, and takes a footer', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRadar(
          cjk: '探知',
          en: 'sector scan',
          meta: 'RNG 40 KM',
          contacts: contacts,
          footer: <Widget>[KkWidgetKey(label: 'CONTACTS 03')],
        ),
      );
      expect(find.byType(KkPlotPointer), findsNothing);
      expect(find.text('CONTACTS 03'), findsOneWidget);
      expect(find.text('RNG 40 KM'), findsOneWidget);
    });

    testWidgets('the beam sweeps and critical contacts blink with motion on', (WidgetTester tester) async {
      await pumpKk(tester, const KkRadar(contacts: contacts), motion: true);
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
      expect(tester.binding.hasScheduledFrame, isTrue);
      // No sweep and nothing critical: nothing ticks.
      await pumpKk(tester, KkRadar(contacts: contacts.sublist(0, 1), sweep: false), motion: true);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('survives odd contacts, ranges and sizes in both themes', (WidgetTester tester) async {
      const List<KkRadarContact> odd = <KkRadarContact>[
        KkRadarContact(id: '', bearing: double.nan, range: double.nan, level: KkLevel.offline),
        KkRadarContact(id: 'FAR', bearing: 720.5, range: 1e300, level: KkLevel.caution),
        KkRadarContact(id: 'NEG', bearing: -90, range: -5),
        KkRadarContact(id: 'INF', bearing: double.infinity, range: double.infinity, level: KkLevel.critical),
      ];
      for (final KkCondition condition in KkCondition.values) {
        for (final double range in const <double>[100, 0, -4, double.nan, double.infinity]) {
          for (final Size size in const <Size>[Size(400, 400), Size(30, 30), Size(10, 300), Size.zero]) {
            await pumpKk(
              tester,
              KkBox(
                width: size.width,
                height: size.height,
                child: KkRadar(
                  cjk: '探知',
                  en: 'scan',
                  contacts: odd,
                  range: range,
                  rings: -3,
                  selectedId: 'FAR',
                  onContactHover: (KkRadarContact? c) {},
                ),
              ),
              condition: condition,
            );
            expect(tester.takeException(), isNull, reason: 'range $range at $size');
          }
        }
      }
      await pumpKk(tester, const KkRadar(rings: 100000));
      expect(tester.takeException(), isNull);
    });
  });

  group('KkWaterfall', () {
    final List<List<double?>> rows = <List<double?>>[
      for (int r = 0; r < 10; r++) <double?>[for (int b = 0; b < 10; b++) -100.0 + r + b * 5],
    ];

    testWidgets('spectrum strip, spectrogram, axis and legend', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkWaterfall(
          cjk: '周波数',
          en: 'spectrum',
          rows: rows,
          startFrequency: 2400,
          endFrequency: 2480,
          min: -120,
          max: -40,
          lowLabel: '-120 dBm',
          highLabel: '-40 dBm',
        ),
      );
      // 32 strip + 1 line + 160 spectrogram + 18 axis.
      expect(tester.getSize(find.byType(KkCanvas)), const Size(798, 32 + 1 + 160 + 18));
      expect(find.byType(KkRampKey), findsOneWidget);
      expect(find.text('-120 dBm'), findsOneWidget);
      expect(find.text('-40 dBm'), findsOneWidget);
    });

    testWidgets('the crosshair reports bin, sweep, frequency and level', (WidgetTester tester) async {
      final List<KkWaterfallProbe?> seen = <KkWaterfallProbe?>[];
      // 200 x 133: 32 strip, 1 line, 100 spectrogram = 10 x 10 cells of 20 x 10.
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 133,
          child: KkWaterfall(
            frame: false,
            legend: false,
            rows: rows,
            capacity: 10,
            startFrequency: 100,
            endFrequency: 190,
            axisLabels: const <String>[],
            onProbe: seen.add,
          ),
        ),
      );
      final Rect plot = plotRect(tester, find.byType(KkWaterfall));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plot.topLeft + const Offset(105, 33 + 45));
      await tester.pump();
      expect(seen.single!.bin, 5);
      expect(seen.single!.row, 4);
      expect(seen.single!.frequency, 150);
      expect(seen.single!.level, -100.0 + 4 + 25);
      // The spectrum strip is not part of the spectrogram.
      await pointer.moveTo(plot.topLeft + const Offset(105, 10));
      await tester.pump();
      expect(seen.last, isNull);
      await pointer.moveTo(plot.topLeft + const Offset(199, 132));
      await tester.pump();
      expect(seen.last!.bin, 9);
      expect(seen.last!.row, 9);
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      expect(seen.last, isNull);
    });

    testWidgets('rows beyond the data probe as empty', (WidgetTester tester) async {
      final List<KkWaterfallProbe?> seen = <KkWaterfallProbe?>[];
      await pumpKk(
        tester,
        KkBox(
          width: 200,
          height: 133,
          child: KkWaterfall(frame: false, legend: false, rows: rows.sublist(0, 2), capacity: 10, onProbe: seen.add),
        ),
      );
      final Rect plot = plotRect(tester, find.byType(KkWaterfall));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plot.topLeft + const Offset(15, 33 + 85));
      await tester.pump();
      expect(seen.single!.row, 8);
      expect(seen.single!.level, isNull);
      expect(seen.single!.frequency, isNull);
    });

    testWidgets('survives empty, ragged and non-finite sweeps at any size', (WidgetTester tester) async {
      final List<List<List<double?>>> cases = <List<List<double?>>>[
        <List<double?>>[],
        <List<double?>>[<double?>[]],
        <List<double?>>[<double?>[1], <double?>[1, 2, 3], <double?>[]],
        <List<double?>>[<double?>[4, 4, 4]],
        <List<double?>>[<double?>[null, double.nan, double.infinity, -1e300, 1e300]],
      ];
      final TestGesture pointer = await mouse(tester);
      for (final List<List<double?>> r in cases) {
        for (final Size size in const <Size>[Size(400, 300), Size(40, 40), Size(10, 10), Size.zero]) {
          for (final KkCondition condition in KkCondition.values) {
            await pumpKk(
              tester,
              KkBox(
                width: size.width,
                height: size.height,
                child: KkWaterfall(
                  cjk: '周波数',
                  en: 'spectrum',
                  rows: r,
                  capacity: -5,
                  startFrequency: double.nan,
                  endFrequency: 5,
                  axisLabels: const <String>['LOW', 'A LABEL THAT IS FAR TOO LONG TO FIT', 'HIGH'],
                  onProbe: (KkWaterfallProbe? p) {},
                ),
              ),
              condition: condition,
            );
            await pointer.moveTo(const Offset(30, 90));
            await tester.pump();
            await pointer.moveTo(const Offset(9999, 9999));
            await tester.pump();
            expect(tester.takeException(), isNull, reason: '$r at $size');
          }
        }
      }
    });
  });
}
