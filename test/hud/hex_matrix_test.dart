import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

List<KkHexCell> _cells(int n) => <KkHexCell>[
  for (int i = 0; i < n; i++) KkHexCell(id: 'N-${i.toString().padLeft(2, '0')}', value: '$i%', level: KkLevel.nominal),
];

Rect _cellRect(WidgetTester tester, String id) =>
    tester.getRect(find.ancestor(of: find.text(id), matching: find.byType(KkSurface)));

void main() {
  setUpAll(loadKkFonts);

  testWidgets('cells are 64 × 73.92, 4px apart, odd rows shifted by half a cell', (WidgetTester tester) async {
    await pumpKk(tester, KkHexMatrix(columns: 3, cells: _cells(7)));
    final Rect first = _cellRect(tester, 'N-00');
    expect(first.size.width, 64);
    expect(first.size.height, closeTo(73.92, 1e-6));
    expect(_cellRect(tester, 'N-01').left - first.left, 68);
    // Second row: half a cell to the right, three quarters down plus the gap.
    final Rect fourth = _cellRect(tester, 'N-03');
    expect(fourth.left - first.left, 34);
    expect(fourth.top - first.top, closeTo(73.92 * 0.75 + 4 * 0.866, 1e-6));
    // Third row is back in line with the first.
    expect(_cellRect(tester, 'N-06').left, first.left);
    final Size size = tester.getSize(find.byType(KkHexMatrix));
    expect(size.width, 3 * 68 - 4 + 34);
    expect(size.height, closeTo(73.92 + 2 * (73.92 * 0.75 + 4 * 0.866), 1e-6));
  });

  testWidgets('wraps to the width it is given', (WidgetTester tester) async {
    Future<int> columnsAt(double width) async {
      await pumpKk(tester, KkBox(width: width, child: KkHexMatrix(cells: _cells(10))));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkHexMatrix)).width, lessThanOrEqualTo(width));
      return tester.allRenderObjects.whereType<RenderKkHexMatrix>().first.resolvedColumns;
    }

    // One row fits ten cells in 676px (10×68 − 4).
    expect(await columnsAt(676), 10);
    // Below that the shifted rows need 34px more: 5×68 − 4 + 34 = 370.
    expect(await columnsAt(370), 5);
    expect(await columnsAt(369), 4);
    expect(await columnsAt(10), 1);
  });

  testWidgets('is eight cells wide when the width is not limited', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkScroll(axis: Axis.horizontal, child: KkHexMatrix(cells: _cells(20))),
      size: const Size(400, 400),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkHexMatrix)).width, 8 * 68 - 4 + 34);
  });

  testWidgets('custom cell size and gap', (WidgetTester tester) async {
    await pumpKk(tester, KkHexMatrix(columns: 2, cellWidth: 100, gap: 10, cells: _cells(2)));
    final Rect first = _cellRect(tester, 'N-00');
    expect(first.size.width, 100);
    expect(first.size.height, closeTo(115.5, 1e-6));
    expect(_cellRect(tester, 'N-01').left - first.left, 110);
  });

  testWidgets('taps land inside the hexagon only, even where rows interlock', (WidgetTester tester) async {
    final List<String> taps = <String>[];
    await pumpKk(
      tester,
      KkHexMatrix(columns: 3, cells: _cells(6), onCellTap: (KkHexCell cell) => taps.add(cell.id)),
    );
    final Rect first = _cellRect(tester, 'N-00');
    await tester.tapAt(first.center);
    expect(taps, <String>['N-00']);

    // The top-left corner of the bounding box is outside the hexagon.
    await tester.tapAt(first.topLeft + const Offset(3, 3));
    expect(taps, <String>['N-00']);

    // This point is inside the bounding boxes of N-00 (row 1) and N-03
    // (row 2) but only inside the hexagon of N-03.
    final Rect fourth = _cellRect(tester, 'N-03');
    await tester.tapAt(Offset(fourth.center.dx, fourth.top + 6));
    expect(taps, <String>['N-00', 'N-03']);
    await tester.tapAt(Offset(first.left + 4, first.bottom - 8));
    expect(taps, <String>['N-00', 'N-03'], reason: 'the bottom-left corner of a cell belongs to nobody');
  });

  testWidgets('cells are focusable and answer Enter; void cells are inert', (WidgetTester tester) async {
    final List<String> taps = <String>[];
    await pumpKk(
      tester,
      KkHexMatrix(
        columns: 3,
        cells: const <KkHexCell>[
          KkHexCell.empty(),
          KkHexCell(id: 'N-01', level: KkLevel.critical),
          KkHexCell(id: 'N-02', level: KkLevel.offline, value: '---'),
        ],
        onCellTap: (KkHexCell cell) => taps.add(cell.id),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, <String>['N-01'], reason: 'the void cell is skipped by focus');
    expect(find.bySemanticsLabel('N-01 CRITICAL'), findsOneWidget);
    expect(find.bySemanticsLabel('N-02 --- OFFLINE'), findsOneWidget);

    // The void cell takes no taps.
    await tester.tapAt(tester.getTopLeft(find.byType(KkHexMatrix)) + const Offset(32, 37));
    expect(taps, <String>['N-01']);
  });

  testWidgets('hover reports the cell and then null', (WidgetTester tester) async {
    final List<String?> hovers = <String?>[];
    await pumpKk(
      tester,
      KkHexMatrix(columns: 2, cells: _cells(2), onCellHover: (KkHexCell? cell) => hovers.add(cell?.id)),
    );
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_cellRect(tester, 'N-01').center);
    await tester.pump();
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(hovers, <String?>['N-01', null]);
  });

  testWidgets('cells pop in one after another, 22ms apart', (WidgetTester tester) async {
    await pumpKk(tester, KkHexMatrix(columns: 4, cells: _cells(4)), motion: true);
    double opacity(String id) =>
        tester.widget<Opacity>(find.ancestor(of: find.text(id), matching: find.byType(Opacity)).first).opacity;
    double scale(String id) {
      final Transform t = tester.widget(find.ancestor(of: find.text(id), matching: find.byType(Transform)).first);
      return t.transform.storage[0];
    }

    expect(opacity('N-00'), 0);
    // 200ms base delay: the first cell starts at 200, the fourth at 266.
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity('N-00'), greaterThan(0));
    expect(opacity('N-03'), 0);
    expect(scale('N-00'), lessThan(1));
    // Half way (360ms for the first cell) it has overshot to 1.08.
    await tester.pump(const Duration(milliseconds: 115));
    expect(opacity('N-00'), 1);
    expect(scale('N-00'), greaterThan(1));
    await tester.pump(const Duration(milliseconds: 400));
    for (final String id in <String>['N-00', 'N-01', 'N-02', 'N-03']) {
      expect(opacity(id), 1);
      expect(scale(id), 1);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty and oversized input do not throw', (WidgetTester tester) async {
    await pumpKk(tester, const KkHexMatrix(cells: <KkHexCell>[]));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(KkHexMatrix)), Size.zero);
    await pumpKk(
      tester,
      const KkBox(
        width: 10,
        height: 10,
        child: KkHexMatrix(
          columns: 0,
          cells: <KkHexCell>[KkHexCell(id: 'A-VERY-LONG-IDENTIFIER', value: '1234567890123', level: KkLevel.caution)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
