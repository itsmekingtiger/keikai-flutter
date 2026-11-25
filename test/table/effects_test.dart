import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
import 'util.dart';

List<KkTableColumn<Pump>> _columns() => <KkTableColumn<Pump>>[
  KkTableColumn<Pump>(
    id: 'id',
    en: 'id',
    width: const KkTableWidth.fixed(80),
    cell: (BuildContext _, Pump p) => KkText(p.id),
  ),
  nameColumn(),
  flowColumn(),
];

Widget _table(
  List<Pump> rows, {
  bool motion = true,
  bool flash = true,
  bool entrance = false,
  KkTableSort? sort,
  String? filter,
  int? pageSize,
  int? page,
  double? height,
  ScrollController? controller,
  bool boot = false,
  bool free = false,
}) => kkHarness(
  _maybeScroll(
    free,
    KkBox(
      width: 600,
      height: height,
      child: KkDataTable<Pump>(
        rows: rows,
        rowKey: pumpKey,
        rowLevel: (Pump p) => p.level,
        columns: _columns(),
        flashChanges: flash,
        entrance: entrance,
        boot: boot,
        sort: sort,
        filter: filter,
        pageSize: pageSize,
        page: page,
        scrollController: controller,
      ),
    ),
  ),
  motion: motion,
);

/// In a scroll view the table has no height limit and builds every row.
Widget _maybeScroll(bool scroll, Widget child) => scroll ? KkScroll(child: child) : child;

List<Pump> _with(List<Pump> rows, String id, Pump Function(Pump p) change) => <Pump>[
  for (final Pump p in rows) p.id == id ? change(p) : p,
];

/// The opacity of the entrance flicker of the row that shows [text].
double _flicker(WidgetTester tester, String text) => tester
    .widget<FadeTransition>(find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  setUpAll(loadKkFonts);

  group('a changed value flashes its cell', () {
    testWidgets('signal, then signal-dim after a quarter, then clear: .9s, six steps each part', (
      WidgetTester tester,
    ) async {
      const KkColors c = KkColors.standby;
      await tester.pumpWidget(_table(pumps));
      await tester.pump(const Duration(seconds: 1));
      expect(lookOf(tester, 'P-01').flashes, isEmpty);

      await tester.pumpWidget(_table(_with(pumps, 'P-01', (Pump p) => p.copyWith(flow: 210))));
      // The flash starts in the frame of the change, on the flow column only.
      List<Color?> flashes() => lookOf(tester, 'P-01').flashes;
      expect(flashes(), <Color?>[null, null, c.signal]);
      expect(lookOf(tester, 'P-02').flashes, isEmpty);
      // First part: 225ms in six steps of 37.5ms from signal to signal-dim.
      await tester.pump(const Duration(milliseconds: 36));
      expect(flashes()[2], c.signal);
      await tester.pump(const Duration(milliseconds: 4));
      expect(flashes()[2], Color.lerp(c.signal, c.signalDim, 1 / 6));
      await tester.pump(const Duration(milliseconds: 160));
      expect(flashes()[2], Color.lerp(c.signal, c.signalDim, 5 / 6));
      // Second part: 675ms in six steps of 112.5ms from signal-dim to nothing.
      await tester.pump(const Duration(milliseconds: 26));
      expect(flashes()[2], c.signalDim);
      await tester.pump(const Duration(milliseconds: 114));
      expect(flashes()[2]!.a, closeTo(5 / 6, 1e-6));
      expect(flashes()[2]!.r, c.signalDim.r);
      await tester.pump(const Duration(milliseconds: 550));
      expect(flashes()[2]!.a, closeTo(1 / 6, 1e-6));
      await tester.pump(const Duration(milliseconds: 11));
      expect(flashes(), isEmpty);
      // Nothing keeps ticking.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the flash is painted behind the cell, as wide as its column', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await tester.pumpWidget(_table(pumps));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(_with(pumps, 'P-03', (Pump p) => p.copyWith(name: 'feed water b'))));
      final RenderBox row = rowOf(tester, 'P-03');
      // name is the second column: 80 to 502 of the 598px row.
      expect(row, paints..rect(rect: const Rect.fromLTWH(80, 0, 422, 32), color: c.signal));
    });

    testWidgets('every change flashes again, and two cells flash on their own clocks', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      List<Pump> rows = pumps;
      await tester.pumpWidget(_table(rows));
      await tester.pump(const Duration(seconds: 1));
      rows = _with(rows, 'P-01', (Pump p) => p.copyWith(flow: 1));
      await tester.pumpWidget(_table(rows));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lookOf(tester, 'P-01').flashes[2]!.a, closeTo(1, 1e-6));
      // The name changes 300ms into the flow's flash.
      rows = _with(rows, 'P-01', (Pump p) => p.copyWith(name: 'loop a2'));
      await tester.pumpWidget(_table(rows));
      expect(lookOf(tester, 'P-01').flashes[1], c.signal);
      expect(lookOf(tester, 'P-01').flashes[2], c.signalDim);
      // The flow changes again: its flash starts over.
      rows = _with(rows, 'P-01', (Pump p) => p.copyWith(flow: 2));
      await tester.pumpWidget(_table(rows));
      expect(lookOf(tester, 'P-01').flashes[2], c.signal);
      await tester.pump(const Duration(milliseconds: 899));
      expect(lookOf(tester, 'P-01').flashes[2], isNotNull);
      await tester.pump(const Duration(milliseconds: 2));
      expect(lookOf(tester, 'P-01').flashes, isEmpty);
    });

    testWidgets('never on the first build, on a sort, a filter or a page change, or without a change', (
      WidgetTester tester,
    ) async {
      final List<Pump> rows = manyPumps(8);
      await tester.pumpWidget(_table(rows, pageSize: 4, page: 0));
      for (final String id in idsInOrder(tester)) {
        expect(lookOf(tester, id).flashes, isEmpty, reason: id);
      }
      await tester.pump(const Duration(seconds: 1));
      for (final Widget next in <Widget>[
        _table(rows, pageSize: 4, page: 0, sort: const KkTableSort('flow', KkSortDirection.descending)),
        _table(rows, pageSize: 4, page: 1),
        _table(rows, pageSize: 4, page: 0, filter: 'row'),
        _table(rows, pageSize: 4, page: 0),
        // The same values in new objects.
        _table(manyPumps(8), pageSize: 4, page: 0),
      ]) {
        await tester.pumpWidget(next);
        for (final String id in idsInOrder(tester)) {
          expect(lookOf(tester, id).flashes, isEmpty, reason: id);
          expect(lookOf(tester, id).shift, isNull, reason: id);
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets('a row that appears has nothing to compare with; NaN equals NaN', (WidgetTester tester) async {
      await tester.pumpWidget(_table(const <Pump>[Pump('P-01', 'a', double.nan)]));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(const <Pump>[Pump('P-01', 'a', double.nan), Pump('P-02', 'b', 2)]));
      expect(lookOf(tester, 'P-01').flashes, isEmpty);
      expect(lookOf(tester, 'P-02').flashes, isEmpty);
    });

    testWidgets('switched off, or with motion off, nothing flashes', (WidgetTester tester) async {
      final List<Pump> changed = _with(pumps, 'P-01', (Pump p) => p.copyWith(flow: 1, level: KkLevel.caution));
      await tester.pumpWidget(_table(pumps, flash: false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(changed, flash: false));
      expect(lookOf(tester, 'P-01').flashes, isEmpty);
      expect(lookOf(tester, 'P-01').shift, isNull);

      await tester.pumpWidget(_table(pumps, motion: false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(changed, motion: false));
      expect(lookOf(tester, 'P-01').flashes, isEmpty);
      expect(lookOf(tester, 'P-01').shift, isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('a changed level strobes the row', () {
    testWidgets('three times in 1.2s, at 45% of the new level\'s colour', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await tester.pumpWidget(_table(pumps));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(_with(pumps, 'P-01', (Pump p) => p.copyWith(level: KkLevel.caution))));
      final Color lit = kkFade(c.caution, 0.45);
      Color? shift() => lookOf(tester, 'P-01').shift;
      expect(shift(), lit);
      expect(lookOf(tester, 'P-02').shift, isNull);
      // On for 17% (204ms), off for 17%, three times.
      final List<(int, bool)> expected = <(int, bool)>[
        (100, true), (203, true), (205, false), (407, false), (409, true), (611, true), (613, false), //
        (815, false), (817, true), (1019, true), (1021, false), (1199, false),
      ];
      int at = 0;
      for (final (int ms, bool on) in expected) {
        await tester.pump(Duration(milliseconds: ms - at));
        at = ms;
        expect(shift(), on ? lit : null, reason: '$ms ms');
      }
      await tester.pump(const Duration(milliseconds: 2));
      expect(shift(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
      // The strobe is painted over the whole row.
      await tester.pumpWidget(_table(_with(pumps, 'P-01', (Pump p) => p.copyWith(level: KkLevel.offline))));
      final RenderBox row = rowOf(tester, 'P-01');
      expect(row, paints..rect(rect: Offset.zero & row.size, color: kkFade(c.offline, 0.45)));
    });

    testWidgets('a row that turns critical strobes in alert over its new ground', (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await tester.pumpWidget(_table(pumps));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_table(_with(pumps, 'P-03', (Pump p) => p.copyWith(level: KkLevel.critical))));
      expect(lookOf(tester, 'P-03').background, c.alertDeep);
      expect(lookOf(tester, 'P-03').shift, kkFade(c.alert, 0.45));
    });
  });

  group('entrance', () {
    testWidgets('rows flicker in .4s, six steps, 35ms apart after .25s', (WidgetTester tester) async {
      await tester.pumpWidget(_table(pumps, entrance: true));
      expect(_flicker(tester, 'P-01'), 0);
      await tester.pump(const Duration(milliseconds: 249));
      expect(_flicker(tester, 'P-01'), 0);
      // Row 0 starts at 250ms: 40ms in it is half way up the first rise (three of six steps to .9).
      await tester.pump(const Duration(milliseconds: 41));
      expect(_flicker(tester, 'P-01'), closeTo(0.45, 1e-9));
      // Row 2 starts at 320ms.
      expect(_flicker(tester, 'P-03'), 0);
      await tester.pump(const Duration(milliseconds: 41));
      // 331ms: row 0 is 81ms in (.9), row 1 (285ms) is 46ms in, row 2 is 11ms in.
      expect(_flicker(tester, 'P-01'), closeTo(0.9, 1e-9));
      expect(_flicker(tester, 'P-02'), closeTo(0.45, 1e-9));
      expect(_flicker(tester, 'P-03'), 0);
      await tester.pump(const Duration(milliseconds: 40));
      // 371ms: row 0 is 121ms in: the dip to .1.
      expect(_flicker(tester, 'P-01'), closeTo(0.1, 1e-9));
      await tester.pump(const Duration(milliseconds: 60));
      // 431ms: 181ms in: full.
      expect(_flicker(tester, 'P-01'), closeTo(1, 1e-9));
      await tester.pump(const Duration(milliseconds: 40));
      // 471ms: 221ms in: the second dip, to .35.
      expect(_flicker(tester, 'P-01'), closeTo(0.35, 1e-9));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_flicker(tester, 'P-01'), closeTo(1, 1e-9));
      await tester.pump(const Duration(milliseconds: 400));
      for (final String id in <String>['P-01', 'P-02', 'P-03', 'P-04']) {
        expect(_flicker(tester, id), 1);
      }
    });

    testWidgets('a place in a staggered grid adds 60ms per place', (WidgetTester tester) async {
      await tester.pumpWidget(
        kkHarness(
          KkStagger(
            index: 2,
            child: KkBox(
              width: 600,
              child: KkDataTable<Pump>(rows: pumps, rowKey: pumpKey, columns: _columns(), boot: false),
            ),
          ),
          motion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 369));
      expect(_flicker(tester, 'P-01'), 0);
      await tester.pump(const Duration(milliseconds: 42));
      expect(_flicker(tester, 'P-01'), closeTo(0.45, 1e-9));
    });

    testWidgets('rows that scroll into view later do not flicker; rows far down the page wait no longer than row 24', (
      WidgetTester tester,
    ) async {
      final ScrollController vertical = ScrollController();
      addTearDown(vertical.dispose);
      await tester.pumpWidget(_table(manyPumps(200), entrance: true, height: 300, controller: vertical));
      await tester.pump(const Duration(seconds: 2));
      vertical.jumpTo(2000);
      await tester.pump();
      for (final String id in idsInOrder(tester)) {
        expect(_flicker(tester, id), 1, reason: id);
      }

      // A free-height table builds every row at once: row 60 enters with row 24.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_table(manyPumps(61), entrance: true, free: true));
      await tester.pump(const Duration(milliseconds: 250 + 24 * 35 + 41));
      expect(_flicker(tester, 'R-0024'), closeTo(0.45, 1e-9));
      expect(_flicker(tester, 'R-0060'), closeTo(0.45, 1e-9));
      expect(_flicker(tester, 'R-0023'), greaterThan(0.45));
    });

    testWidgets('a sort, a filter or a page change lets the rows flicker in again', (WidgetTester tester) async {
      await tester.pumpWidget(_table(pumps, entrance: true));
      await tester.pump(const Duration(seconds: 2));
      expect(_flicker(tester, 'P-01'), 1);
      await tester.pumpWidget(_table(pumps, entrance: true, sort: const KkTableSort('flow')));
      // Sorted by flow: P-04 (0), P-02 (96), P-03 (118), P-01 (204).
      expect(idsInOrder(tester), <String>['P-04', 'P-02', 'P-03', 'P-01']);
      expect(_flicker(tester, 'P-04'), 0);
      expect(_flicker(tester, 'P-01'), 0);
      await tester.pump(const Duration(milliseconds: 291));
      expect(_flicker(tester, 'P-04'), closeTo(0.45, 1e-9));
      // P-01 is now the fourth row: it starts at 355ms.
      expect(_flicker(tester, 'P-01'), 0);
      await tester.pump(const Duration(seconds: 2));
      expect(_flicker(tester, 'P-01'), 1);
      // New data alone does not replay it.
      await tester.pumpWidget(_table(pumps.toList(), entrance: true, sort: const KkTableSort('flow')));
      expect(_flicker(tester, 'P-04'), 1);
    });

    testWidgets('with motion off, or switched off, rows are simply there', (WidgetTester tester) async {
      await tester.pumpWidget(_table(pumps, entrance: true, motion: false));
      expect(_flicker(tester, 'P-01'), 1);
      await tester.pumpWidget(_table(pumps, entrance: false));
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('the table boots with the 7-step wipe unless told not to', (WidgetTester tester) async {
      Finder boots() => find.ancestor(of: byRuntimeType('KkTableFrame'), matching: find.byType(KkBoot));
      await tester.pumpWidget(_table(pumps));
      final int without = boots().evaluate().length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_table(pumps, boot: true));
      expect(boots().evaluate().length, without + 1);
      final Finder clip = find.descendant(of: boots().first, matching: find.byType(ClipRect)).first;
      double shown() {
        final ClipRect widget = tester.widget<ClipRect>(clip);
        if (widget.clipBehavior == Clip.none) return 1;
        final Size size = tester.getSize(clip);
        return widget.clipper!.getClip(size).width / size.width;
      }

      expect(shown(), 0);
      await tester.pump(const Duration(milliseconds: 61));
      expect(shown(), closeTo(1 / 7, 1e-9));
      await tester.pump(const Duration(milliseconds: 360));
      expect(shown(), 1);
    });
  });
}
