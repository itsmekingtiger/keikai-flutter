import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

const List<KkBarListItem> _items = <KkBarListItem>[
  KkBarListItem(cjk: '管制', en: 'control', value: 482),
  KkBarListItem(cjk: '冷却', en: 'coolant loop', value: 391, level: KkLevel.caution),
  KkBarListItem(en: 'power bus', value: 344),
  KkBarListItem(en: 'standby', value: 0, level: KkLevel.offline, display: '---'),
];

void main() {
  setUpAll(loadKkFonts);

  group('KkBarList', () {
    testWidgets('rows are 24 tall, 6 apart, with rank, label and value', (WidgetTester tester) async {
      await pumpKk(tester, const KkBarList(frame: false, items: _items, unit: 'GB'));
      expect(tester.getSize(find.byType(KkBarList)).height, 4 * 24 + 3 * 6);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);
      expect(find.text('管制'), findsOneWidget);
      expect(find.text('COOLANT LOOP'), findsOneWidget);
      expect(find.text('482'), findsOneWidget);
      expect(find.text('---'), findsOneWidget);
      expect(find.text('GB'), findsNWidgets(4));
      expect(find.byType(KkGlyph), findsNWidgets(2));
      // The value column is 64 wide and right-aligned to the list's edge.
      expect(tester.getTopRight(find.text('GB').first).dx, 800);
      // The track sits between a 20px rank column and the 64px value column.
      final Rect first = tester.getRect(find.text('管制'));
      expect(first.left, closeTo(20 + 8 + 8, 0.6));
    });

    testWidgets('framed: head, 12px padding and the rows', (WidgetTester tester) async {
      await pumpKk(tester, const KkBarList(cjk: '通信量上位', en: 'top talkers', items: _items));
      expect(tester.getSize(find.byType(KkBarList)).height, closeTo(2 + 38.7 + 24 + 114, 1.5));
      expect(find.text('TOP TALKERS'), findsOneWidget);
    });

    testWidgets('no rank column when showRank is false', (WidgetTester tester) async {
      await pumpKk(tester, const KkBarList(frame: false, items: _items, showRank: false));
      expect(find.text('01'), findsNothing);
      expect(tester.getRect(find.text('管制')).left, closeTo(8, 0.6));
    });

    testWidgets('formatter, per-item unit and tap', (WidgetTester tester) async {
      final List<int> taps = <int>[];
      await pumpKk(
        tester,
        KkBarList(
          frame: false,
          items: const <KkBarListItem>[
            KkBarListItem(en: 'alpha', value: 1500, unit: 'MS'),
            KkBarListItem(en: 'beta', value: 250),
          ],
          unit: 'S',
          format: (double v) => v.toStringAsFixed(1),
          onItemTap: taps.add,
        ),
      );
      expect(find.text('1500.0'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      await tester.tap(find.text('BETA'));
      expect(taps, <int>[1]);
      // Rows are focusable when they can be tapped.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, <int>[1, 0]);
    });

    testWidgets('semantics: one image with a summary, or a button per row when tappable', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(tester, const KkBarList(cjk: '通信量上位', en: 'top talkers', unit: 'GB', items: _items));
      expect(
        tester.getSemantics(find.byType(KkChartFrame)),
        matchesSemantics(
          label: '通信量上位 TOP TALKERS',
          value: 'control 482GB, coolant loop 391GB, power bus 344GB, standby ---GB',
          isImage: true,
        ),
      );
      // Nothing inside an image is reachable.
      expect(find.bySemanticsLabel('control 482GB'), findsNothing);

      final List<int> taps = <int>[];
      await pumpKk(tester, KkBarList(cjk: '通信量上位', en: 'top talkers', unit: 'GB', items: _items, onItemTap: taps.add));
      for (final (int i, String label) in <(int, String)>[
        (0, 'control 482GB'),
        (1, 'coolant loop 391GB'),
        (2, 'power bus 344GB'),
        (3, 'standby ---GB'),
      ]) {
        final Finder row = find.bySemanticsLabel(label);
        expect(row, findsOneWidget, reason: label);
        expect(
          tester.getSemantics(row),
          isSemantics(label: label, isButton: true, hasTapAction: true, isFocusable: true),
          reason: label,
        );
        tester.semantics.tap(find.semantics.byLabel(label));
        expect(taps.last, i);
      }
      expect(taps, <int>[0, 1, 2, 3]);
      // The head is plain text beside them.
      expect(find.bySemanticsLabel('TOP TALKERS'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('survives empty, zero, negative, huge and non-finite values', (WidgetTester tester) async {
      const List<List<KkBarListItem>> cases = <List<KkBarListItem>>[
        <KkBarListItem>[],
        <KkBarListItem>[KkBarListItem(value: 0)],
        <KkBarListItem>[KkBarListItem(en: 'a', value: -5), KkBarListItem(en: 'b', value: double.nan)],
        <KkBarListItem>[KkBarListItem(en: 'a', value: double.infinity), KkBarListItem(en: 'b', value: 1e300)],
        <KkBarListItem>[
          KkBarListItem(
            cjk: '管制管制管制管制管制管制管制管制',
            en: 'a label far too long to ever fit inside the track of a bar list row',
            value: 123456789012345,
            level: KkLevel.critical,
          ),
        ],
      ];
      for (final List<KkBarListItem> items in cases) {
        for (final double width in const <double>[0, 30, 120, 800]) {
          await pumpKk(
            tester,
            KkBox(
              width: width,
              child: KkBarList(items: items, max: 100, unit: 'GB'),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$items at $width');
        }
      }
      await pumpKk(tester, const KkBox(width: 300, height: 30, child: KkBarList(items: _items)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fills grow in', (WidgetTester tester) async {
      await pumpKk(tester, const KkBarList(items: _items), motion: true);
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('KkCategoryBar', () {
    const List<KkSlice> segments = <KkSlice>[
      KkSlice(name: 'LOGS', value: 38),
      KkSlice(name: 'VIDEO', value: 22),
      KkSlice(name: 'FREE', value: 40, level: KkLevel.offline),
    ];

    testWidgets('title, meta, a 12px bar and a legend', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkCategoryBar(
          frame: false,
          cjk: '記憶域',
          en: 'storage',
          meta: '060 / 100 TB',
          marker: 0.85,
          segments: segments,
        ),
      );
      expect(find.text('記憶域'), findsOneWidget);
      expect(find.text('STORAGE'), findsOneWidget);
      expect(find.text('060 / 100 TB'), findsOneWidget);
      expect(tester.getSize(find.byType(KkCanvas)), const Size(800, 12));
      expect(find.byType(KkWidgetKey), findsNWidgets(3));
      expect(find.text('38'), findsOneWidget);
      // head 23.25 + 8 + bar 12 + 8 + legend 11
      expect(tester.getSize(find.byType(KkCategoryBar)).height, closeTo(62.3, 1.6));
    });

    testWidgets('framed adds 12px padding and the border', (WidgetTester tester) async {
      await pumpKk(tester, const KkCategoryBar(cjk: '記憶域', en: 'storage', segments: segments));
      expect(tester.getSize(find.byType(KkCategoryBar)).height, closeTo(62.3 + 24 + 2, 1.6));
      expect(tester.getSize(find.byType(KkCanvas)).width, 800 - 24 - 2);
    });

    testWidgets('is 200 wide when the width is free', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(children: <Widget>[KkCategoryBar(frame: false, legend: false, segments: segments)]),
      );
      expect(tester.getSize(find.byType(KkCanvas)).width, 200);
    });

    testWidgets('survives empty, zero, negative and non-finite segments', (WidgetTester tester) async {
      const List<List<KkSlice>> cases = <List<KkSlice>>[
        <KkSlice>[],
        <KkSlice>[KkSlice(name: 'A', value: 0)],
        <KkSlice>[KkSlice(name: 'A', value: -3), KkSlice(name: 'B', value: double.nan)],
        <KkSlice>[KkSlice(name: 'A', value: double.infinity), KkSlice(name: 'B', value: 2)],
        <KkSlice>[
          KkSlice(name: 'A', value: 1),
          KkSlice(name: 'B', value: 1),
          KkSlice(name: 'C', value: 1),
          KkSlice(name: 'D', value: 1),
          KkSlice(name: 'E', value: 1),
        ],
      ];
      for (final List<KkSlice> s in cases) {
        for (final double width in const <double>[0, 6, 200]) {
          for (final double marker in const <double>[-1, 0.5, 9, double.nan]) {
            await pumpKk(
              tester,
              KkBox(
                width: width,
                child: KkCategoryBar(cjk: '記憶域', en: 'storage', meta: 'META', segments: s, marker: marker),
              ),
            );
            expect(tester.takeException(), isNull, reason: '$s at $width, marker $marker');
          }
        }
      }
    });

    testWidgets('total leaves the rest of the bar as an empty track', (WidgetTester tester) async {
      const List<KkSlice> two = <KkSlice>[KkSlice(name: 'A', value: 50), KkSlice(name: 'B', value: 50)];
      Finder bar() => find.descendant(of: find.byType(KkCanvas), matching: find.byType(CustomPaint));
      const KkColors c = KkColors.standby;

      await pumpKk(
        tester,
        const KkBox(width: 402, child: KkCategoryBar(frame: false, legend: false, total: 200, segments: two)),
      );
      // Three parts and two gaps: (402 - 4) / 4 = 99.5 each, the track 199.
      expect(
        tester.renderObject(bar()),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 99.5, 12), color: c.series1)
          ..rect(rect: const Rect.fromLTWH(101.5, 0, 99.5, 12), color: c.series2)
          ..rect(rect: const Rect.fromLTRB(203, 0, 402, 12), color: c.bg200),
      );

      // Without a total, or with one the segments already exceed, they fill the bar.
      for (final double? total in const <double?>[null, 100, 60, 0, -5, double.nan, double.infinity]) {
        await pumpKk(
          tester,
          KkBox(
            width: 402,
            child: KkCategoryBar(frame: false, legend: false, total: total, segments: two),
          ),
        );
        expect(
          tester.renderObject(bar()),
          paints
            ..rect(rect: const Rect.fromLTWH(0, 0, 200, 12), color: c.series1)
            ..rect(rect: const Rect.fromLTWH(202, 0, 200, 12), color: c.series2),
          reason: 'total $total',
        );
        // Two segments and nothing else: no track.
        expect(tester.renderObject(bar()), paintsExactlyCountTimes(#drawRect, 2), reason: 'total $total');
      }

      // A marker is one more rectangle, in ink, across the full bar width.
      await pumpKk(
        tester,
        const KkBox(
          width: 402,
          child: KkCategoryBar(frame: false, legend: false, total: 200, marker: 0.75, segments: two),
        ),
      );
      expect(tester.renderObject(bar()), paintsExactlyCountTimes(#drawRect, 4));
      expect(
        tester.renderObject(bar()),
        paints
          ..rect(color: c.series1)
          ..rect(color: c.series2)
          ..rect(color: c.bg200)
          ..rect(rect: const Rect.fromLTWH(402 * 0.75 - 1, -5, 2, 22), color: c.ink),
      );

      // Nothing used yet: the whole bar is track.
      await pumpKk(
        tester,
        const KkBox(
          width: 402,
          child: KkCategoryBar(
            frame: false,
            legend: false,
            total: 10,
            segments: <KkSlice>[KkSlice(name: 'A', value: 0)],
          ),
        ),
      );
      expect(tester.renderObject(bar()), paints..rect(rect: const Rect.fromLTRB(0, 0, 402, 12), color: c.bg200));
    });

    testWidgets('semantics name the parts and the total', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        const KkCategoryBar(
          cjk: '電力配分',
          en: 'power budget',
          total: 800,
          segments: <KkSlice>[
            KkSlice(name: 'COMPUTE', value: 310),
            KkSlice(name: 'COOLING', value: 220.5),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.byType(KkChartFrame)),
        matchesSemantics(label: '電力配分 POWER BUDGET', value: 'COMPUTE 310, COOLING 220.5, of 800', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('segments grow in', (WidgetTester tester) async {
      await pumpKk(tester, const KkCategoryBar(segments: segments), motion: true);
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('KkStatusTimeline', () {
    const List<KkTimelineRow> rows = <KkTimelineRow>[
      KkTimelineRow(
        cjk: '冷却',
        en: 'coolant',
        spans: <KkTimelineSpan>[
          KkTimelineSpan(KkLevel.nominal, weight: 1, label: 'a'),
          KkTimelineSpan(KkLevel.critical, weight: 1, label: 'b'),
          KkTimelineSpan(KkLevel.nominal, weight: 2, label: 'c'),
        ],
      ),
      KkTimelineRow(en: 'uplink', spans: <KkTimelineSpan>[KkTimelineSpan(KkLevel.offline, weight: 4)], percent: 12.345),
    ];

    testWidgets('names, tracks, percents and the axis', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkStatusTimeline(cjk: '稼働履歴', en: 'uptime', rows: rows, axis: <String>['14:00Z', '02:00Z', '14:00Z']),
      );
      expect(find.text('冷却'), findsOneWidget);
      expect(find.text('COOLANT'), findsOneWidget);
      expect(find.text('UPLINK'), findsOneWidget);
      // 3 of 4 weight units are nominal; the second row's figure is given.
      expect(find.text('75.0'), findsOneWidget);
      expect(find.text('12.3'), findsOneWidget);
      expect(find.text('14:00Z'), findsNWidgets(2));
      // One key for every level present.
      expect(find.byType(KkWidgetKey), findsNWidgets(3));
      expect(find.text('NOMINAL'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      // Tracks are 18 tall and share one width.
      final Finder tracks = find.byType(KkCanvas);
      expect(tracks, findsNWidgets(2));
      expect(tester.getSize(tracks.at(0)).height, 18);
      expect(tester.getSize(tracks.at(0)).width, tester.getSize(tracks.at(1)).width);
      expect(tester.getRect(tracks.at(0)).left, tester.getRect(tracks.at(1)).left);
      // The percent column ends 12px (padding) + 1px (border) from the right edge.
      expect(tester.getTopRight(find.text('%').first).dx, closeTo(800 - 13, 0.6));
    });

    testWidgets('hover and tap report the stretch', (WidgetTester tester) async {
      final List<KkTimelineHit?> seen = <KkTimelineHit?>[];
      final List<KkTimelineHit> taps = <KkTimelineHit>[];
      await pumpKk(tester, KkStatusTimeline(frame: false, rows: rows, onSpanHover: seen.add, onSpanTap: taps.add));
      final Rect first = plotRect(tester, find.byType(KkStatusTimeline));
      final Rect second = plotRect(tester, find.byType(KkStatusTimeline), index: 1);
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(first.topLeft + Offset(first.width * 0.1, 9));
      await tester.pump();
      await pointer.moveTo(first.topLeft + Offset(first.width * 0.4, 9));
      await tester.pump();
      await pointer.moveTo(first.topLeft + Offset(first.width * 0.8, 9));
      await tester.pump();
      await pointer.moveTo(second.center);
      await tester.pump();
      await pointer.moveTo(const Offset(9999, 9999));
      await tester.pump();
      expect(
        <String>[for (final KkTimelineHit? h in seen) h == null ? '-' : '${h.row}:${h.index}:${h.span.label ?? ''}'],
        // Leaving one track for the next clears the hit in between.
        <String>['0:0:a', '0:1:b', '0:2:c', '-', '1:0:', '-'],
      );
      await tester.tapAt(first.topLeft + Offset(first.width * 0.4, 9));
      expect(taps.single.index, 1);
      expect(taps.single.span.level, KkLevel.critical);
    });

    testWidgets('is not interactive without callbacks', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTimeline(rows: rows));
      expect(find.byType(KkPlotPointer), findsNothing);
      expect(find.byType(KkPlotFocus), findsNothing);
    });

    testWidgets('arrow keys walk the stretches; Home, End, Enter and Escape', (WidgetTester tester) async {
      final List<KkTimelineHit?> seen = <KkTimelineHit?>[];
      final List<KkTimelineHit> taps = <KkTimelineHit>[];
      List<String> names() => <String>[
        for (final KkTimelineHit? h in seen) h == null ? '-' : '${h.row}:${h.index}:${h.span.label ?? ''}',
      ];
      await pumpKk(tester, KkStatusTimeline(frame: false, rows: rows, onSpanHover: seen.add, onSpanTap: taps.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowRight, // from nothing: the first stretch
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight, // already at the end: stays
        LogicalKeyboardKey.arrowDown, // the one stretch of the second row
        LogicalKeyboardKey.arrowDown, // no third row: stays
        LogicalKeyboardKey.arrowUp, // back up, to the stretch over its middle
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.arrowLeft, // from nothing, leftwards: the last stretch
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(names(), <String>['0:0:a', '0:1:b', '0:2:c', '1:0:', '0:1:b', '0:0:a', '0:2:c', '-', '0:2:c']);
      expect(taps.single, const KkTimelineHit(0, 2, KkTimelineSpan(KkLevel.nominal, weight: 2, label: 'c')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the keys skip stretches that are not drawn, and focusable: false opts out', (
      WidgetTester tester,
    ) async {
      const List<KkTimelineRow> gappy = <KkTimelineRow>[
        KkTimelineRow(en: 'empty', spans: <KkTimelineSpan>[]),
        KkTimelineRow(
          en: 'gappy',
          spans: <KkTimelineSpan>[
            KkTimelineSpan(KkLevel.nominal, weight: 0, label: 'none'),
            KkTimelineSpan(KkLevel.nominal, label: 'a'),
            KkTimelineSpan(KkLevel.critical, weight: double.nan, label: 'nan'),
            KkTimelineSpan(KkLevel.critical, weight: -2, label: 'neg'),
            KkTimelineSpan(KkLevel.caution, label: 'b'),
          ],
        ),
      ];
      final List<String> seen = <String>[];
      void hear(KkTimelineHit? h) => seen.add(h?.span.label ?? '-');
      await pumpKk(tester, KkStatusTimeline(frame: false, rows: gappy, onSpanHover: hear));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(seen, <String>['a', 'b', 'a']);

      seen.clear();
      await pumpKk(tester, KkStatusTimeline(frame: false, rows: gappy, focusable: false, onSpanHover: hear));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(seen, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cursor follows a stretch that changes under it', (WidgetTester tester) async {
      final List<String> seen = <String>[];
      List<KkTimelineRow> data = rows;
      // The listener rebuilds its parent: that throws if it is called mid-build.
      Widget build() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => KkStatusTimeline(
          frame: false,
          rows: data,
          onSpanHover: (KkTimelineHit? h) =>
              setState(() => seen.add(h == null ? '-' : '${h.row}:${h.index}:${h.span.level?.name}:${h.span.label}')),
        ),
      );
      await pumpKk(tester, build());
      final Rect first = plotRect(tester, find.byType(KkStatusTimeline));
      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(first.topLeft + Offset(first.width * 0.4, 9));
      await tester.pump();
      expect(seen, <String>['0:1:critical:b']);

      // The same data in new objects is not a change.
      data = <KkTimelineRow>[
        KkTimelineRow(
          en: 'coolant',
          spans: <KkTimelineSpan>[
            for (final KkTimelineSpan s in rows[0].spans) KkTimelineSpan(s.level, weight: s.weight, label: s.label),
          ],
        ),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen.length, 1);

      // The stretch under the pointer recovers.
      data = const <KkTimelineRow>[
        KkTimelineRow(
          en: 'coolant',
          spans: <KkTimelineSpan>[
            KkTimelineSpan(KkLevel.nominal, label: 'a'),
            KkTimelineSpan(KkLevel.caution, label: 'b2'),
            KkTimelineSpan(KkLevel.nominal, weight: 2, label: 'c'),
          ],
        ),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen.last, '0:1:caution:b2');

      // And then is gone: the cursor lets go, and the one stretch left, which
      // now lies under the resting pointer, takes it.
      data = const <KkTimelineRow>[
        KkTimelineRow(
          en: 'coolant',
          spans: <KkTimelineSpan>[KkTimelineSpan(KkLevel.nominal, label: 'a')],
        ),
      ];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen, <String>['0:1:critical:b', '0:1:caution:b2', '-', '0:0:nominal:a']);
      data = const <KkTimelineRow>[];
      await tester.pumpWidget(kkHarness(build()));
      await tester.pump();
      expect(seen.last, '-');
      expect(tester.takeException(), isNull);
    });

    test('stretches and hits compare by value', () {
      expect(const KkTimelineSpan(KkLevel.nominal), const KkTimelineSpan(KkLevel.nominal));
      expect(const KkTimelineSpan(KkLevel.nominal).hashCode, const KkTimelineSpan(KkLevel.nominal).hashCode);
      expect(const KkTimelineSpan(null, weight: double.nan), const KkTimelineSpan(null, weight: double.nan));
      expect(const KkTimelineSpan(KkLevel.nominal) == const KkTimelineSpan(KkLevel.caution), isFalse);
      expect(const KkTimelineSpan(KkLevel.nominal) == const KkTimelineSpan(KkLevel.nominal, weight: 2), isFalse);
      expect(const KkTimelineSpan(KkLevel.nominal) == const KkTimelineSpan(KkLevel.nominal, label: 'x'), isFalse);
      const KkTimelineHit hit = KkTimelineHit(1, 2, KkTimelineSpan(KkLevel.offline));
      expect(hit, const KkTimelineHit(1, 2, KkTimelineSpan(KkLevel.offline)));
      expect(hit == const KkTimelineHit(1, 2, KkTimelineSpan(KkLevel.nominal)), isFalse);
      expect(hit == const KkTimelineHit(1, 3, KkTimelineSpan(KkLevel.offline)), isFalse);
    });

    testWidgets('percent column and legend can be hidden', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTimeline(rows: rows, showPercent: false, legend: false));
      expect(find.text('%'), findsNothing);
      expect(find.byType(KkWidgetKey), findsNothing);
    });

    testWidgets('survives empty rows, odd weights and tiny sizes', (WidgetTester tester) async {
      final List<List<KkTimelineRow>> cases = <List<KkTimelineRow>>[
        const <KkTimelineRow>[],
        const <KkTimelineRow>[KkTimelineRow(spans: <KkTimelineSpan>[])],
        const <KkTimelineRow>[
          KkTimelineRow(
            en: 'x',
            spans: <KkTimelineSpan>[
              KkTimelineSpan(KkLevel.nominal, weight: 0),
              KkTimelineSpan(KkLevel.caution, weight: -3),
              KkTimelineSpan(null, weight: double.nan),
              KkTimelineSpan(KkLevel.offline, weight: double.infinity),
            ],
          ),
        ],
        <KkTimelineRow>[
          KkTimelineRow(
            cjk: '冷却冷却冷却冷却冷却冷却冷却冷却冷却冷却',
            en: 'a name much longer than the timeline is wide',
            spans: <KkTimelineSpan>[
              for (int i = 0; i < 300; i++) const KkTimelineSpan(KkLevel.nominal, weight: 0.001),
              const KkTimelineSpan(KkLevel.critical, weight: 1000),
            ],
            percent: double.nan,
          ),
        ],
      ];
      for (final List<KkTimelineRow> r in cases) {
        for (final Size size in const <Size>[Size(800, 600), Size(60, 60), Size.zero]) {
          await pumpKk(
            tester,
            KkBox(
              width: size.width,
              height: size == const Size(800, 600) ? null : size.height,
              child: KkStatusTimeline(rows: r, axis: const <String>['A', 'B'], onSpanHover: (KkTimelineHit? hit) {}),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$r at $size');
        }
      }
    });

    testWidgets('rows wipe in', (WidgetTester tester) async {
      await pumpKk(tester, const KkStatusTimeline(rows: rows), motion: true);
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
