import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/table/band.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

Widget _table({
  String? code = 'TBL-01',
  String? cjk = '機器',
  String? en = 'pumps',
  String? meta,
  bool filterable = false,
  String? filter,
  ValueChanged<String>? onFilterChanged,
  List<Pump> rows = pumps,
  Set<Object>? selected,
  List<KkTableBulkAction> bulk = const <KkTableBulkAction>[],
  ValueChanged<Set<Object>>? onSelectionChanged,
  List<Widget> actions = const <Widget>[],
}) => KkBox(
  width: 700,
  child: KkDataTable<Pump>(
    code: code,
    cjk: cjk,
    en: en,
    meta: meta,
    filterable: filterable,
    filter: filter,
    onFilterChanged: onFilterChanged,
    rows: rows,
    rowKey: pumpKey,
    columns: basicColumns(),
    selection: KkTableSelection.multi,
    selected: selected,
    bulkActions: bulk,
    onSelectionChanged: onSelectionChanged,
    actions: actions,
  ),
);

RenderKkBox _bandBox(WidgetTester tester) => tester.renderObject<RenderKkBox>(
  find.descendant(of: byRuntimeType('KkTableBand'), matching: find.byType(KkBox)).first,
);

/// The plate of the bulk button that reads [label].
RenderKkSurface _plate(WidgetTester tester, String label) => tester.renderObject<RenderKkSurface>(
  find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(KkTableBulkButton)),
    matching: find.byType(KkSurface),
  ),
);

/// The blink of the bulk button that reads [label]: 1 when lit, .2 when dim.
double _blink(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.descendant(
              of: find.ancestor(of: find.text(label), matching: find.byType(KkTableBulkButton)),
              matching: find.byType(KkSurface),
            ),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// Whether the reading [label] of a bulk button is the one that shows.
bool _reads(WidgetTester tester, String label) =>
    tester.widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first).opacity == 1;

void main() {
  setUpAll(loadKkFonts);

  group('band', () {
    testWidgets('40 high on bg-200 with a 1px line; code block, title and meta as in the CSS', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table(meta: '04 ROWS'));
      const KkColors c = KkColors.standby;
      expect(tester.getRect(byRuntimeType('KkTableBand')), const Rect.fromLTWH(1, 1, 698, 40));
      final KkDecoration d = _bandBox(tester).decoration!;
      expect(d.fill, c.bg200);
      expect(d.edges.bottom, KkSide(c.line, width: 1));

      // Code block: 12px in, text, then 8 + 14 for the slant; as high as the band above its line.
      final Rect code = tester.getRect(find.text('TBL-01'));
      final RenderKkSurface block = tester.renderObject<RenderKkSurface>(
        find.ancestor(of: find.text('TBL-01'), matching: find.byType(KkSurface)),
      );
      final Rect blockRect = globalRect(block);
      expect(blockRect.left, 1);
      expect(blockRect.top, 1);
      expect(blockRect.height, 39);
      expect(code.left - blockRect.left, 12);
      expect(blockRect.right - code.right, closeTo(8 + 14, 0.01));
      expect(block.fill, c.signal);
      expect(block.shape, const KkShape.slant(14));
      final TextStyle codeStyle = styleOf(tester, 'TBL-01');
      expect(codeStyle.fontSize, 11);
      expect(codeStyle.fontWeight, FontWeight.w600);
      expect(codeStyle.letterSpacing, closeTo(0.66, 1e-9));
      expect(codeStyle.color, c.onFill);

      // Title: 8 after the block (the row's gap) plus 4, CJK 17 and EN 11 / 700 / .14em.
      expect(tester.getRect(find.text('機器')).left - blockRect.right, closeTo(8 + 4, 0.01));
      expect(styleOf(tester, '機器').fontSize, 17);
      expect(styleOf(tester, '機器').color, c.ink);
      final TextStyle en = styleOf(tester, 'PUMPS');
      expect(en.fontSize, 11);
      expect(en.fontWeight, FontWeight.w700);
      expect(en.letterSpacing, closeTo(1.54, 1e-9));
      expect(en.color, c.inkDim);

      final TextStyle meta = styleOf(tester, '04 ROWS');
      expect(meta.fontSize, 12);
      expect(meta.fontWeight, FontWeight.w500);
      expect(meta.color, c.ink);
      // 4px padding, then the band's 8px right padding.
      expect(tester.getRect(find.text('04 ROWS')).right, 1 + 698 - 8 - 4);
    });

    testWidgets('without a code block the title starts 12px in', (WidgetTester tester) async {
      await pumpKk(tester, _table(code: null));
      expect(tester.getRect(find.text('機器')).left, 1 + 12);
    });

    testWidgets('actions sit at the right, after the filter', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _table(
          filterable: true,
          actions: <Widget>[KkIconButton(icon: KkIcons.refresh, semanticLabel: 'Refresh', onPressed: () {})],
        ),
      );
      final Rect button = tester.getRect(find.byType(KkIconButton));
      final Rect field = tester.getRect(byRuntimeType('KkTableFilterField'));
      expect(button.right, 1 + 698 - 8);
      expect(button.left - field.right, 8);
    });
  });

  group('filter field', () {
    testWidgets('200 × 28 on the void ground, mono 12, capitals placeholder', (WidgetTester tester) async {
      await pumpKk(tester, _table(filterable: true));
      const KkColors c = KkColors.standby;
      final Rect field = tester.getRect(byRuntimeType('KkTableFilterField'));
      expect(field.size, const Size(200, 28));
      expect(field.center.dy, closeTo(1 + 19.5, 0.01));
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: byRuntimeType('KkTableFilterField'), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.fill, c.bg000);
      expect(box.decoration!.edges.top, KkSide(c.inkFaint, width: 1));
      final TextStyle placeholder = styleOf(tester, 'FILTER');
      expect(placeholder.color, c.inkFaint);
      expect(placeholder.letterSpacing, closeTo(12 * 0.14, 1e-9));
      // The clear button keeps its 20px place while it is hidden.
      final Finder clear = find.descendant(of: byRuntimeType('KkTableFilterField'), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(clear).opacity, 0);
      expect(tester.getSize(clear), const Size(20, 20));
      expect(tester.getRect(clear).right, field.right - 1 - 4);
    });

    testWidgets('typing narrows the rows, the border turns signal, and the clear button brings them back', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      await pumpKk(tester, _table(filterable: true, onFilterChanged: changes.add));
      await tester.tap(byRuntimeType('KkTableFilterField'));
      await tester.pump();
      final RenderKkBox box = tester.renderObject<RenderKkBox>(
        find.descendant(of: byRuntimeType('KkTableFilterField'), matching: find.byType(KkBox)).first,
      );
      expect(box.decoration!.edges.top.color, KkColors.standby.signal);
      final RenderKkFocusRing ring = tester.renderObject<RenderKkFocusRing>(
        find.descendant(of: byRuntimeType('KkTableFilterField'), matching: find.byType(KkFocusRing)).first,
      );
      expect(ring.visible, isTrue);
      expect(ring.offset, 1);

      await tester.enterText(find.byType(EditableText), 'COOL');
      await tester.pump();
      expect(changes, <String>['COOL']);
      expect(idsInOrder(tester), <String>['P-01', 'P-02']);
      final Finder clear = find.descendant(of: byRuntimeType('KkTableFilterField'), matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(clear).opacity, 1);
      await tester.tap(find.bySemanticsLabel('Clear filter'));
      await tester.pump();
      expect(changes.last, '');
      expect(idsInOrder(tester), <String>['P-01', 'P-02', 'P-03', 'P-04']);
      expect(tester.widget<Opacity>(clear).opacity, 0);
    });

    testWidgets('a filter that matches nothing shows the no-match block', (WidgetTester tester) async {
      await pumpKk(tester, _table(filterable: true));
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pump();
      expect(idsInOrder(tester), isEmpty);
      expect(find.text('該当無'), findsOneWidget);
      expect(find.text('NO MATCH'), findsOneWidget);
    });

    testWidgets('only searchable columns with text are looked at; a predicate replaces the rule', (
      WidgetTester tester,
    ) async {
      Widget build({bool Function(Pump row, String query)? predicate}) => KkDataTable<Pump>(
        filterable: true,
        filterPredicate: predicate,
        rows: pumps,
        rowKey: pumpKey,
        columns: <KkTableColumn<Pump>>[
          KkTableColumn<Pump>(id: 'id', en: 'id', value: (Pump p) => p.id, searchable: false),
          nameColumn(),
          KkTableColumn<Pump>(id: 'x', en: 'x', cell: (BuildContext _, Pump p) => const KkText('feed')),
        ],
      );
      await pumpKk(tester, build());
      await tester.enterText(find.byType(EditableText), 'p-0');
      await tester.pump();
      // The id column is not searched.
      expect(find.text('NO MATCH'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  FEED ');
      await tester.pump();
      // Trimmed, case ignored; the builder column's "feed" is not text the table knows.
      expect(idsInOrder(tester), <String>['P-03']);

      await pumpKk(tester, build(predicate: (Pump row, String query) => row.flow != null && row.flow! > 100));
      await tester.enterText(find.byType(EditableText), 'anything');
      await tester.pump();
      expect(idsInOrder(tester), <String>['P-01', 'P-03']);
    });

    testWidgets('a controlled filter shows what the owner gives', (WidgetTester tester) async {
      final List<String> asked = <String>[];
      await pumpKk(tester, _table(filterable: true, filter: 'spare', onFilterChanged: asked.add));
      expect(idsInOrder(tester), <String>['P-04']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'spare');
      await pumpKk(tester, _table(filterable: true, filter: 'feed', onFilterChanged: asked.add));
      expect(idsInOrder(tester), <String>['P-03']);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'feed');
    });
  });

  group('selection band', () {
    final List<KkTableBulkAction> noActions = <KkTableBulkAction>[];

    testWidgets('same place and height, solid signal, count block and label in the CSS sizes', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, _table());
      final Rect before = tester.getRect(byRuntimeType('KkTableBand'));
      final double headerTop = globalRect(cellRows(tester).first).top;
      await pumpKk(tester, _table(selected: const <Object>{'P-01', 'P-02', 'P-04'}, bulk: noActions));
      const KkColors c = KkColors.standby;
      expect(tester.getRect(byRuntimeType('KkTableBand')), before);
      expect(globalRect(cellRows(tester).first).top, headerTop);
      final KkDecoration d = _bandBox(tester).decoration!;
      expect(d.fill, c.signal);
      expect(d.edges.bottom.color, c.signal);

      final RenderKkSurface block = tester.renderObject<RenderKkSurface>(
        find.ancestor(of: find.text('03'), matching: find.byType(KkSurface)),
      );
      expect(block.fill, c.bg000);
      expect(block.shape, const KkShape.slant(14));
      final TextStyle count = styleOf(tester, '03');
      expect(count.fontSize, 20);
      expect(count.fontWeight, FontWeight.w600);
      expect(count.color, c.signal);
      expect(tester.getRect(find.text('03')).left, 1 + 12);
      expect(styleOf(tester, '選択').fontSize, 17);
      expect(styleOf(tester, '選択').color, c.onFill);
      expect(styleOf(tester, 'SELECTED').fontSize, 11);
      expect(styleOf(tester, 'SELECTED').color, c.onFill);
      expect(tester.getRect(find.text('選択')).left - globalRect(block).right, closeTo(8 + 4, 0.01));
      // The close button is an icon button in the dark ink of the band.
      expect(tester.widget<KkIconButton>(find.byType(KkIconButton)).style!.ink, c.onFill);
      expect(tester.getRect(find.byType(KkIconButton)).right, 1 + 698 - 8);
    });

    testWidgets('the band wipes in over .25s in five steps', (WidgetTester tester) async {
      Widget build(Set<Object> selected) => kkHarness(_table(selected: selected), motion: true);
      await tester.pumpWidget(build(const <Object>{}));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(build(const <Object>{'P-01'}));
      double shown() {
        final Finder clip = find.ancestor(of: find.text('SELECTED'), matching: find.byType(ClipRect)).first;
        final ClipRect widget = tester.widget<ClipRect>(clip);
        if (widget.clipBehavior == Clip.none) return 1;
        final Size size = tester.getSize(clip);
        return widget.clipper!.getClip(size).width / size.width;
      }

      expect(shown(), 0);
      await tester.pump(const Duration(milliseconds: 49));
      expect(shown(), 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(shown(), closeTo(0.2, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(), closeTo(0.6, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown(), 1);
      // A second row does not wipe again.
      await tester.pumpWidget(build(const <Object>{'P-01', 'P-02'}));
      expect(shown(), 1);
      await tester.pump(const Duration(milliseconds: 30));
      expect(shown(), 1);
    });

    testWidgets('bulk actions: 28 high plates on the void ground; a plain action acts at once', (
      WidgetTester tester,
    ) async {
      traditionalHighlights();
      final List<Set<Object>> done = <Set<Object>>[];
      await pumpKk(
        tester,
        _table(
          selected: const <Object>{'P-01', 'P-03'},
          bulk: <KkTableBulkAction>[
            KkTableBulkAction(label: 'acknowledge', cjk: '確認', icon: KkIcons.check, onPressed: done.add),
            const KkTableBulkAction(label: 'export'),
          ],
        ),
      );
      const KkColors c = KkColors.standby;
      final RenderKkSurface plate = _plate(tester, 'ACKNOWLEDGE');
      expect(plate.size.height, 28);
      expect(plate.fill, c.bg000);
      expect(plate.shape, const KkShape.plate(6));
      expect(styleOf(tester, 'ACKNOWLEDGE').fontSize, 12);
      expect(styleOf(tester, 'ACKNOWLEDGE').fontWeight, FontWeight.w700);
      expect(styleOf(tester, 'ACKNOWLEDGE').letterSpacing, closeTo(1.2, 1e-9));
      expect(styleOf(tester, 'ACKNOWLEDGE').color, c.signal);
      expect(styleOf(tester, '確認').fontSize, 13);
      // 12px padding, the icon, 6, the CJK word, 5, the label, 12.
      final Rect plateRect = globalRect(plate);
      expect(tester.getRect(find.text('ACKNOWLEDGE')).right, closeTo(plateRect.right - 12, 0.01));
      expect(tester.getRect(find.text('ACKNOWLEDGE')).left - tester.getRect(find.text('確認')).right, closeTo(5, 0.01));

      final TestGesture pointer = await mouse(tester);
      await pointer.moveTo(plateRect.center);
      await tester.pump();
      expect(_plate(tester, 'ACKNOWLEDGE').fill, c.bg300);

      await tester.tap(find.text('ACKNOWLEDGE'));
      await tester.pump();
      expect(done, <Set<Object>>[
        <Object>{'P-01', 'P-03'},
      ]);
      // An action without a callback is off.
      expect(styleOf(tester, 'EXPORT').color, c.inkFaint);
    });

    testWidgets('a danger action arms on the first press, blinks, and acts on the second', (WidgetTester tester) async {
      final List<Set<Object>> done = <Set<Object>>[];
      await tester.pumpWidget(
        kkHarness(
          _table(
            selected: const <Object>{'P-02'},
            bulk: <KkTableBulkAction>[
              KkTableBulkAction(
                label: 'trip',
                cjk: '遮断',
                danger: true,
                confirmLabel: 'confirm trip',
                onPressed: done.add,
              ),
            ],
          ),
          motion: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      const KkColors c = KkColors.standby;
      expect(styleOf(tester, 'TRIP').color, c.alert);
      expect(_reads(tester, 'TRIP'), isTrue);
      expect(_reads(tester, 'CONFIRM TRIP'), isFalse);
      final double width = _plate(tester, 'TRIP').size.width;
      // Both readings are laid out: the button is as wide as the longer one.
      expect(width, greaterThan(tester.getSize(find.text('CONFIRM TRIP')).width));

      await tester.tap(find.text('TRIP'));
      await tester.pump();
      expect(done, isEmpty);
      expect(_plate(tester, 'TRIP').fill, c.alert);
      expect(_plate(tester, 'TRIP').size.width, width);
      expect(_reads(tester, 'TRIP'), isFalse);
      expect(_reads(tester, 'CONFIRM TRIP'), isTrue);
      expect(styleOf(tester, 'CONFIRM TRIP').color, c.onFill);
      // It blinks once a second: lit for the first half, dimmed to .2 for the second.
      final List<double> seen = <double>[];
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        seen.add(_blink(tester, 'TRIP'));
      }
      expect(seen.toSet(), <double>{1, 0.2});
      int flips = 0;
      for (int i = 1; i < seen.length; i++) {
        if (seen[i] != seen[i - 1]) flips++;
      }
      expect(flips, inInclusiveRange(3, 4));

      await tester.tap(find.text('CONFIRM TRIP'));
      await tester.pump();
      expect(done, <Set<Object>>[
        <Object>{'P-02'},
      ]);
      expect(_plate(tester, 'TRIP').fill, c.bg000);
      expect(_reads(tester, 'TRIP'), isTrue);
      expect(_blink(tester, 'TRIP'), 1);
    });

    testWidgets('an armed action stands down after its timeout, on Escape, on a press elsewhere, on focus loss', (
      WidgetTester tester,
    ) async {
      final List<Set<Object>> done = <Set<Object>>[];
      await pumpKk(
        tester,
        _table(
          selected: const <Object>{'P-02'},
          bulk: <KkTableBulkAction>[
            KkTableBulkAction(label: 'trip', danger: true, armTimeout: const Duration(seconds: 3), onPressed: done.add),
            KkTableBulkAction(label: 'other', onPressed: (Set<Object> _) {}),
          ],
        ),
      );
      const KkColors c = KkColors.standby;
      bool armed() => _plate(tester, 'TRIP').fill == c.alert;

      // Timeout.
      await tester.tap(find.text('TRIP'));
      await tester.pump();
      expect(armed(), isTrue);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(armed(), isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(armed(), isFalse);

      // A press elsewhere.
      await tester.tap(find.text('TRIP'));
      await tester.pump();
      expect(armed(), isTrue);
      await tester.tap(find.text('coolant loop a'));
      await tester.pump();
      expect(armed(), isFalse);

      // Escape while the rows have the focus (the press above gave it to them).
      await tester.tap(find.text('TRIP'));
      await tester.pump();
      expect(armed(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(armed(), isFalse);

      // Escape and focus loss on the button itself.
      FocusNode nodeOf(String label) => Focus.of(
        tester.element(
          find.descendant(
            of: find.ancestor(of: find.text(label), matching: find.byType(KkTableBulkButton)),
            matching: find.byType(KkSurface),
          ),
        ),
      );
      nodeOf('TRIP').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(armed(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(armed(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(armed(), isTrue);
      nodeOf('OTHER').requestFocus();
      // One pump moves the focus, the next shows what that changed.
      await tester.pump();
      await tester.pump();
      expect(armed(), isFalse);
      expect(done, isEmpty);
    });

    testWidgets('a change of the selection disarms', (WidgetTester tester) async {
      List<KkTableBulkAction> bulk() => <KkTableBulkAction>[
        KkTableBulkAction(label: 'trip', danger: true, onPressed: (Set<Object> _) {}),
      ];
      await pumpKk(tester, _table(selected: const <Object>{'P-02'}, bulk: bulk()));
      await tester.tap(find.text('TRIP'));
      await tester.pump();
      expect(_plate(tester, 'TRIP').fill, KkColors.standby.alert);
      // The same rows keep it armed.
      await pumpKk(tester, _table(selected: const <Object>{'P-02'}, bulk: bulk()));
      expect(_plate(tester, 'TRIP').fill, KkColors.standby.alert);
      await pumpKk(tester, _table(selected: const <Object>{'P-02', 'P-03'}, bulk: bulk()));
      expect(_plate(tester, 'TRIP').fill, KkColors.standby.bg000);
    });

    testWidgets('with motion off an armed action is steadily lit', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _table(
          selected: const <Object>{'P-02'},
          bulk: <KkTableBulkAction>[KkTableBulkAction(label: 'trip', danger: true, onPressed: (Set<Object> _) {})],
        ),
      );
      await tester.tap(find.text('TRIP'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        expect(_blink(tester, 'TRIP'), 1);
      }
    });

    testWidgets('focus rings on the signal band are dark', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _table(
          selected: const <Object>{'P-02'},
          bulk: <KkTableBulkAction>[KkTableBulkAction(label: 'trip', onPressed: (Set<Object> _) {})],
        ),
      );
      final RenderKkFocusRing ring = tester.renderObject<RenderKkFocusRing>(
        find.descendant(of: find.byType(KkTableBulkButton), matching: find.byType(KkFocusRing)),
      );
      expect(ring.color, KkColors.standby.bg000);
      // Outside the band the ring keeps the theme's colour.
      final RenderKkFocusRing sort = tester.renderObject<RenderKkFocusRing>(
        find.descendant(of: byRuntimeType('KkTableHeaderLabel'), matching: find.byType(KkFocusRing)).first,
      );
      expect(sort.color, KkColors.standby.focus);
    });
  });

  group('band row', () {
    // lead 50, title 100, fixed 30, filter 200 (least 120), fixed 28; five
    // gaps of 8 (the room after the title is an item too): 448 in all.
    Widget row({double? width = 600, void Function()? onTitleDown}) => KkBox(
      width: width,
      height: 40,
      child: KkTableBandRow(
        children: <Widget>[
          const KkTableBandSlot(part: KkTableBandPart.lead, child: SizedBox(width: 50)),
          KkTableBandSlot(
            part: KkTableBandPart.title,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent _) => onTitleDown?.call(),
              child: const SizedBox(width: 100, height: 20),
            ),
          ),
          const SizedBox(width: 30, height: 12),
          const KkTableBandSlot(part: KkTableBandPart.filter, child: SizedBox(height: 28)),
          const SizedBox(width: 28, height: 28),
        ],
      ),
    );

    List<Rect> rects(WidgetTester tester) {
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      final List<Rect> out = <Rect>[];
      band.visitChildren((RenderObject child) => out.add(globalRect(child as RenderBox)));
      return out;
    }

    testChecked('with room: children centred, 8 apart, the spare room after the title', (WidgetTester tester) async {
      await pumpKk(tester, row());
      expect(rects(tester), const <Rect>[
        Rect.fromLTWH(0, 0, 50, 40),
        Rect.fromLTWH(58, 10, 100, 20),
        Rect.fromLTWH(326, 14, 30, 12),
        Rect.fromLTWH(364, 6, 200, 28),
        Rect.fromLTWH(572, 6, 28, 28),
      ]);
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      expect(band.size, const Size(600, 40));
      expect(band.getMaxIntrinsicWidth(40), 448);
      // The title can go and the field can be 120.
      expect(band.getMinIntrinsicWidth(40), 448 - 100 - 80);
      expect(band.getMinIntrinsicHeight(double.infinity), 28);
      expect(band, isNot(paints..clipRect()));
    });

    testChecked('too narrow by 60: title and field give up the same share of their widths', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, row(width: 388));
      final List<Rect> r = rects(tester);
      // 60 over 100 + 200: each keeps four fifths. The title keeps its size and is cut.
      expect(r[1], const Rect.fromLTWH(58, 10, 100, 20));
      expect(r[2].left, closeTo(58 + 80 + 16, 1e-9));
      expect(r[3].width, closeTo(160, 1e-9));
      expect(r[4].right, closeTo(388, 1e-9));
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      expect(band, paints..clipRect(rect: const Rect.fromLTWH(58, 0, 80, 40)));
    });

    testChecked('narrower still: the field stops at its least width and the title gives up the rest', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, row(width: 300));
      List<Rect> r = rects(tester);
      // 148 too narrow: the field gives 80, the title 68.
      expect(r[3].width, 120);
      expect(r[2].left, closeTo(58 + 32 + 16, 1e-9));
      expect(r[4].right, closeTo(300, 1e-9));
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      expect(band, paints..clipRect(rect: const Rect.fromLTWH(58, 0, 32, 40)));

      // Nothing left to give: the title is gone and the rest runs out at the right.
      await pumpKk(tester, row(width: 200));
      r = rects(tester);
      expect(band.size, const Size(200, 40));
      expect(r[2].left, 58 + 16);
      expect(r[3], const Rect.fromLTWH(112, 6, 120, 28));
      expect(r[4].left, 240);
      expect(band, isNot(paints..clipRect()));
      expect(tester.takeException(), isNull);
    });

    testChecked('a cut title is only hit where it shows', (WidgetTester tester) async {
      int downs = 0;
      await pumpKk(tester, row(width: 388, onTitleDown: () => downs++));
      // The title is 58…158 and shows up to 138.
      await tester.tapAt(const Offset(130, 20));
      expect(downs, 1);
      await tester.tapAt(const Offset(145, 20));
      expect(downs, 1);

      await pumpKk(tester, row(onTitleDown: () => downs++));
      await tester.tapAt(const Offset(145, 20));
      expect(downs, 2);
    });

    testChecked('without a width it takes what its children need; without a height the tallest', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        const KkRow(
          shrinkWrap: true,
          children: <Widget>[
            KkColumn(
              shrinkWrap: true,
              children: <Widget>[
                KkTableBandRow(
                  children: <Widget>[
                    KkTableBandSlot(part: KkTableBandPart.lead, child: SizedBox(width: 50, height: 16)),
                    KkTableBandSlot(part: KkTableBandPart.title, child: SizedBox(width: 100, height: 20)),
                    KkTableBandSlot(part: KkTableBandPart.filter, child: SizedBox(height: 28)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      // 50 + 100 + 200 and three gaps.
      expect(band.size, const Size(374, 28));
      expect(rects(tester), const <Rect>[
        Rect.fromLTWH(0, 6, 50, 16),
        Rect.fromLTWH(58, 4, 100, 20),
        Rect.fromLTWH(174, 0, 200, 28),
      ]);
    });

    testChecked('an empty row and a row of one child lay out', (WidgetTester tester) async {
      await pumpKk(tester, const KkBox(width: 120, height: 40, child: KkTableBandRow()));
      expect(tester.getSize(find.byType(KkTableBandRow)), const Size(120, 40));
      await pumpKk(
        tester,
        const KkBox(
          width: 120,
          height: 40,
          child: KkTableBandRow(
            children: <Widget>[KkTableBandSlot(part: KkTableBandPart.filter, child: SizedBox(height: 28))],
          ),
        ),
      );
      // Alone, the field still gives way down to its least width, not further.
      expect(rects(tester).single, const Rect.fromLTWH(0, 6, 120, 28));
      await pumpKk(
        tester,
        const KkBox(
          width: 90,
          height: 40,
          child: KkTableBandRow(
            children: <Widget>[KkTableBandSlot(part: KkTableBandPart.filter, child: SizedBox(height: 28))],
          ),
        ),
      );
      expect(rects(tester).single, const Rect.fromLTWH(0, 6, 120, 28));
      expect(tester.takeException(), isNull);
    });
  });

  group('narrow tables', () {
    Widget narrow(double width, {Set<Object>? selected, ValueChanged<Set<Object>>? onSelectionChanged}) => KkBox(
      width: width,
      child: KkDataTable<Pump>(
        code: 'TBL-01',
        cjk: '機器',
        en: 'pumps',
        meta: '04 ROWS',
        filterable: true,
        rows: pumps,
        rowKey: pumpKey,
        columns: basicColumns(),
        selection: selected == null ? KkTableSelection.none : KkTableSelection.multi,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        bulkActions: <KkTableBulkAction>[
          KkTableBulkAction(label: 'export', onPressed: (Set<Object> _) {}),
          KkTableBulkAction(label: 'trip', danger: true, onPressed: (Set<Object> _) {}),
        ],
      ),
    );

    final Finder titleSlot = find.byWidgetPredicate(
      (Widget w) => w is KkTableBandSlot && w.part == KkTableBandPart.title,
    );

    testChecked('the filter field gives way with the title, down to 120, and the band stays 40 high', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, narrow(700));
      final double title = tester.renderObject<RenderBox>(titleSlot).size.width;
      expect(tester.getSize(byRuntimeType('KkTableFilterField')), const Size(200, 28));
      // What the row needs: its four children as they are now, and four
      // gaps (the room after the title is an item of the row as well).
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      double natural = 4 * 8;
      band.visitChildren((RenderObject child) => natural += (child as RenderBox).size.width);

      // The frame's 1px sides and the band's 8px at the right come on top.
      await pumpKk(tester, narrow(natural + 10 - 40));
      Rect field = tester.getRect(byRuntimeType('KkTableFilterField'));
      expect(field.width, closeTo(200 - 40 * 200 / (title + 200), 1e-6));
      expect(field.right, closeTo(natural + 10 - 40 - 1 - 8, 1e-6));
      expect(tester.getSize(byRuntimeType('KkTableBand')).height, 40);
      // The title is still laid out whole; the row cuts it.
      expect(tester.renderObject<RenderBox>(titleSlot).size.width, title);
      final double shown = title - 40 * title / (title + 200);
      expect(band, _clipsNear(Rect.fromLTWH(_titleLeft(tester), 0, shown, 39)));

      await pumpKk(tester, narrow(natural + 10 - 150));
      field = tester.getRect(byRuntimeType('KkTableFilterField'));
      expect(tester.getSize(byRuntimeType('KkTableFilterField')), const Size(120, 28));
      expect(field.right, closeTo(natural + 10 - 150 - 1 - 8, 1e-6));

      // Far too narrow: nothing throws, the field keeps its 120.
      await pumpKk(tester, narrow(150));
      expect(tester.getSize(byRuntimeType('KkTableFilterField')), const Size(120, 28));
      expect(tester.getSize(byRuntimeType('KkTableBand')), const Size(148, 40));
      expect(tester.takeException(), isNull);
    });

    testChecked('the selection label gives way so that the actions stay in reach', (WidgetTester tester) async {
      await pumpKk(tester, narrow(700, selected: const <Object>{'P-01', 'P-02'}));
      final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
      // Count, label, two actions and the clear button: five gaps with the room after the label.
      double natural = 5 * 8;
      band.visitChildren((RenderObject child) => natural += (child as RenderBox).size.width);
      final double label = tester.renderObject<RenderBox>(titleSlot).size.width;

      final List<Set<Object>> changes = <Set<Object>>[];
      await pumpKk(
        tester,
        narrow(natural + 10 - 30, selected: const <Object>{'P-01', 'P-02'}, onSelectionChanged: changes.add),
      );
      final Rect clear = tester.getRect(find.byType(KkIconButton));
      expect(clear.right, closeTo(natural + 10 - 30 - 1 - 8, 1e-6));
      // The label is laid out whole and shows 30px less.
      expect(tester.renderObject<RenderBox>(titleSlot).size.width, label);
      expect(band, _clipsNear(Rect.fromLTWH(_titleLeft(tester), 0, label - 30, 39)));
      // The buttons are whole and still work.
      for (final Element button in find.byType(KkTableBulkButton).evaluate()) {
        final Rect r = globalRect(button.renderObject! as RenderBox);
        expect(r.left, greaterThan(_titleLeft(tester) + label - 30));
        expect(r.right, lessThan(clear.left));
      }
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      expect(changes, <Set<Object>>[<Object>{}]);
    });
  });
}

/// The left edge of the band's title inside the band's row.
double _titleLeft(WidgetTester tester) {
  final RenderBox band = tester.renderObject<RenderBox>(find.byType(KkTableBandRow));
  final RenderBox title = tester.renderObject<RenderBox>(
    find.byWidgetPredicate((Widget w) => w is KkTableBandSlot && w.part == KkTableBandPart.title),
  );
  return title.localToGlobal(Offset.zero).dx - band.localToGlobal(Offset.zero).dx;
}

/// Painting through a clip that is [rect], give or take the rounding of sums
/// of text widths.
PaintPattern _clipsNear(Rect rect) => paints
  ..something((Symbol method, List<dynamic> arguments) {
    if (method != #clipRect) return false;
    final Rect r = arguments[0] as Rect;
    return (r.left - rect.left).abs() < 1e-6 &&
        (r.top - rect.top).abs() < 1e-6 &&
        (r.right - rect.right).abs() < 1e-6 &&
        (r.bottom - rect.bottom).abs() < 1e-6;
  });
