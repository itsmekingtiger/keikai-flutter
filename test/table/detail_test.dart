import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

const Key _detailKey = ValueKey<String>('detail');

Widget _table({
  List<Pump> rows = pumps,
  Set<Object>? expanded,
  ValueChanged<Set<Object>>? onExpandedChanged,
  bool Function(Pump p)? canExpand,
  double width = 600,
  double? height,
  ScrollController? controller,
  Widget Function(BuildContext context, Pump p)? detail,
}) => KkBox(
  width: width,
  height: height,
  child: KkDataTable<Pump>(
    rows: rows,
    rowKey: pumpKey,
    columns: basicColumns(),
    expanded: expanded,
    onExpandedChanged: onExpandedChanged,
    canExpand: canExpand,
    scrollController: controller,
    detail: detail ?? (BuildContext _, Pump p) => KkBox(key: _detailKey, height: 40, child: KkText('about ${p.id}')),
  ),
);

/// The expander button of the row that shows [id].
Finder _expander(String id) => inRow(id, find.byType(KkIconButton));

void main() {
  setUpAll(loadKkFonts);

  testChecked('a detail builder adds a 28px expander column with a 24px chevron button per row', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _table());
    expect(find.byType(KkIconButton), findsNWidgets(4));
    final KkIconButton button = tester.widget<KkIconButton>(_expander('P-01'));
    expect(button.icon, KkIcons.chevronRight);
    expect(button.size, KkIconButtonSize.sm);
    expect(tester.getRect(_expander('P-01')), const Rect.fromLTWH(1 + 2, 1 + 2 + 30 + 4, 24, 24));
    expect(find.bySemanticsLabel('Expand row'), findsNWidgets(4));
    // The id column starts after the 28px.
    expect(tester.getRect(find.text('P-01')).left, 1 + 28 + 8);
  });

  testChecked('pressing the expander opens the block under the row in the same frame and pushes the rest down', (
    WidgetTester tester,
  ) async {
    final List<Set<Object>> changes = <Set<Object>>[];
    await pumpKk(tester, _table(onExpandedChanged: changes.add));
    final double before = tableRect(tester).height;
    await tester.tap(_expander('P-02'));
    await tester.pump();
    expect(changes, <Set<Object>>[
      <Object>{'P-02'},
    ]);
    expect(tester.widget<KkIconButton>(_expander('P-02')).icon, KkIcons.chevronDown);
    expect(find.bySemanticsLabel('Collapse row'), findsOneWidget);
    // Row 1 ends at 1 + 2 + 30 + 64 = 97. The block: 12 + 40 + 12 padding and its 1px line.
    final Rect block = tester.getRect(find.ancestor(of: find.byKey(_detailKey), matching: find.byType(KkBoot)).first);
    expect(block.top, 97);
    expect(block.height, 64);
    expect(block.width, 598);
    expect(rowRectOf(tester, 'P-03').top, 97 + 65);
    expect(rowRectOf(tester, 'P-04').top, 97 + 65 + 32);
    // A table without a height grows by the block.
    expect(tableRect(tester).height, before + 65);
    final RenderBox frame = frameOf(tester);
    expect(frame.getDryLayout(frame.constraints), frame.size);

    await tester.tap(_expander('P-02'));
    await tester.pump();
    expect(changes.last, isEmpty);
    expect(find.byKey(_detailKey), findsNothing);
    expect(tableRect(tester).height, before);
    expect(rowRectOf(tester, 'P-03').top, 97);
  });

  testChecked(
    'the block: void ground, a line under it, 12 / 16 / 12 / 32 padding, the corner mark, dim mono 12 / 1.6',
    (WidgetTester tester) async {
      const KkColors c = KkColors.standby;
      await pumpKk(tester, _table(expanded: const <Object>{'P-01'}));
      final Finder boot = find.ancestor(of: find.byKey(_detailKey), matching: find.byType(KkBoot)).first;
      final RenderKkBox ground = tester.renderObject<RenderKkBox>(
        find.ancestor(of: boot, matching: find.byType(KkBox)).first,
      );
      expect(ground.decoration!.fill, c.bg000);
      expect(ground.decoration!.edges.bottom, KkSide(c.line, width: 1));
      final Rect block = tester.getRect(boot);
      final Rect content = tester.getRect(find.byKey(_detailKey));
      expect(content.left - block.left, 32);
      expect(content.top - block.top, 12);
      expect(block.bottom - content.bottom, 12);
      final TextStyle style = DefaultTextStyle.of(tester.element(find.byKey(_detailKey))).style;
      expect(style.fontSize, 12);
      expect(style.height, 1.6);
      expect(style.color, c.inkDim);
      expect(style.fontFamily, contains('IBM Plex Mono'));
      // The mark: an 8px corner, 2px lines on its left and top, 16 / 12 into the block.
      final Finder mark = find.descendant(of: boot, matching: find.byType(KkBox)).last;
      expect(tester.getRect(mark), Rect.fromLTWH(block.left + 16, block.top + 12, 8, 8));
      final KkEdges edges = tester.renderObject<RenderKkBox>(mark).decoration!.edges;
      expect(edges.left, KkSide(c.signal, width: 2));
      expect(edges.top, KkSide(c.signal, width: 2));
      expect(edges.right, KkSide.none);
      expect(edges.bottom, KkSide.none);
    },
  );

  testChecked('content that needs the width it gets: the block is as high as the wrapped text', (
    WidgetTester tester,
  ) async {
    Widget build(double width) => _table(
      width: width,
      expanded: const <Object>{'P-01'},
      detail: (BuildContext _, Pump p) => const Text(
        'The auxiliary pump takes over when the pressure in loop A falls under one hundred and twenty kilopascal.',
      ),
    );
    await pumpKk(tester, build(600));
    final double wide = rowRectOf(tester, 'P-02').top;
    await pumpKk(tester, build(300));
    final double narrow = rowRectOf(tester, 'P-02').top;
    expect(narrow, greaterThan(wide));
    // The text wraps inside the padding.
    final Rect text = tester.getRect(find.textContaining('auxiliary pump'));
    expect(text.left, 1 + 32);
    expect(text.right, lessThanOrEqualTo(1 + 298 - 16));
    expect(rowRectOf(tester, 'P-02').top, closeTo(text.bottom + 12 + 1, 0.01));
  });

  testChecked('a controlled set of open rows changes only when the owner says so; rows that cannot open are skipped', (
    WidgetTester tester,
  ) async {
    final List<Set<Object>> asked = <Set<Object>>[];
    Widget build(Set<Object> expanded) =>
        _table(expanded: expanded, onExpandedChanged: asked.add, canExpand: (Pump p) => p.id != 'P-04');
    await pumpKk(tester, build(const <Object>{'P-01', 'P-04', 'gone'}));
    // P-04 cannot open, whatever the set says, and has no button.
    expect(find.byKey(_detailKey), findsOneWidget);
    expect(_expander('P-04'), findsNothing);
    expect(find.byType(KkIconButton), findsNWidgets(3));
    await tester.tap(_expander('P-02'));
    await tester.pump();
    expect(asked.last, <Object>{'P-01', 'P-04', 'gone', 'P-02'});
    expect(find.byKey(_detailKey), findsOneWidget);
    await pumpKk(tester, build(const <Object>{'P-01', 'P-02'}));
    expect(find.byKey(_detailKey), findsNWidgets(2));
    await pumpKk(tester, build(const <Object>{}));
    expect(find.byKey(_detailKey), findsNothing);
  });

  testWidgets('the block wipes in over .3s in six steps', (WidgetTester tester) async {
    await tester.pumpWidget(kkHarness(_table(), motion: true));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(_expander('P-01'));
    await tester.pump();
    final Finder clip = find
        .descendant(
          of: find.ancestor(of: find.byKey(_detailKey), matching: find.byType(KkBoot)).first,
          matching: find.byType(ClipRect),
        )
        .first;
    double shown() {
      final ClipRect widget = tester.widget<ClipRect>(clip);
      if (widget.clipBehavior == Clip.none) return 1;
      final Size size = tester.getSize(clip);
      return widget.clipper!.getClip(size).width / size.width;
    }

    expect(shown(), 0);
    await tester.pump(const Duration(milliseconds: 49));
    expect(shown(), 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(shown(), closeTo(1 / 6, 1e-9));
    await tester.pump(const Duration(milliseconds: 150));
    expect(shown(), closeTo(4 / 6, 1e-9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(), 1);
    // The ground is there from the first frame; the row below already has its place.
    expect(rowRectOf(tester, 'P-02').top, 1 + 2 + 30 + 32 + 65);
  });

  testChecked('in a table that scrolls, an open block adds exactly its height to what can be scrolled', (
    WidgetTester tester,
  ) async {
    final ScrollController vertical = ScrollController();
    addTearDown(vertical.dispose);
    Widget build(Set<Object> expanded) =>
        _table(rows: manyPumps(40), height: 300, controller: vertical, expanded: expanded);
    await pumpKk(tester, build(const <Object>{}));
    // 298 - rail 2 - header 30 = 266 of viewport over 40 rows.
    expect(vertical.position.maxScrollExtent, 40 * 32 - 266);
    await pumpKk(tester, build(const <Object>{'R-0001', 'R-0030'}));
    await tester.pump();
    // The second block is far below the view and has never been built: it counts with the estimate.
    expect(vertical.position.maxScrollExtent, 40 * 32 - 266 + 65 + 96);
    expect(rowRectOf(tester, 'R-0002').top, 1 + 2 + 30 + 64 + 65);
    // Jumping to the end builds it and measures it; the frame after that has the real height,
    // and the offset is back in range without a spring.
    vertical.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(vertical.position.maxScrollExtent, 40 * 32 - 266 + 65 + 65);
    expect(vertical.offset, vertical.position.maxScrollExtent);
    expect(rowRectOf(tester, 'R-0039').bottom, 299);
    // Scrolled so that the block is in view: it sits between its row and the next.
    vertical.jumpTo(1000);
    await tester.pump();
    final Rect block = tester.getRect(find.ancestor(of: find.byKey(_detailKey), matching: find.byType(KkBoot)).first);
    expect(block.top, rowRectOf(tester, 'R-0030').bottom);
    expect(rowRectOf(tester, 'R-0031').top, block.bottom + 1);
    expect(rowRectOf(tester, 'R-0030').top, 1 + 2 + 30 + (30 * 32 + 65) - 1000);
  });

  testWidgets('Right opens the focused row, Left closes it, Enter toggles it', (WidgetTester tester) async {
    Set<Object> open = <Object>{};
    await pumpKk(tester, _table(onExpandedChanged: (Set<Object> s) => open = s, canExpand: (Pump p) => p.id != 'P-03'));
    await tester.tap(find.text('coolant loop a'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(open, <Object>{'P-01'});
    // Already open: Right does nothing more.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(open, <Object>{'P-01'});
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(open, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(open, <Object>{'P-01'});
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(open, isEmpty);
    // A row that cannot open ignores the keys.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(open, isEmpty);
  });
}
