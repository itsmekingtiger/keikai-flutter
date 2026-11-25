import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/table/layout.dart';

/// A row of test data.
class Pump {
  const Pump(this.id, this.name, this.flow, {this.level, this.load = 0, this.note});

  final String id;
  final String name;
  final double? flow;
  final KkLevel? level;
  final double load;
  final String? note;

  Pump copyWith({String? name, double? flow, KkLevel? level, double? load}) =>
      Pump(id, name ?? this.name, flow ?? this.flow, level: level ?? this.level, load: load ?? this.load, note: note);
}

const List<Pump> pumps = <Pump>[
  Pump('P-01', 'coolant loop a', 204, level: KkLevel.nominal, load: 0.4),
  Pump('P-02', 'coolant loop b', 96, level: KkLevel.critical, load: 0.9),
  Pump('P-03', 'feed water', 118, level: KkLevel.caution, load: 0.7),
  Pump('P-04', 'spare', 0, level: KkLevel.offline),
];

/// [count] rows `R-0000` … with a flow equal to their position.
List<Pump> manyPumps(int count) => <Pump>[
  for (int i = 0; i < count; i++) Pump('R-${i.toString().padLeft(4, '0')}', 'row $i', i.toDouble()),
];

Object pumpKey(Pump p) => p.id;

KkTableColumn<Pump> idColumn({KkTableWidth width = const KkTableWidth.fixed(80)}) =>
    KkTableColumn<Pump>(id: 'id', en: 'id', width: width, value: (Pump p) => p.id, sortable: true);

KkTableColumn<Pump> nameColumn({KkTableWidth width = const KkTableWidth.flex()}) =>
    KkTableColumn<Pump>(id: 'name', en: 'name', width: width, value: (Pump p) => p.name, sortable: true);

KkTableColumn<Pump> flowColumn({KkTableWidth width = const KkTableWidth.fixed(96)}) => KkTableColumn<Pump>(
  id: 'flow',
  en: 'flow',
  unit: 'L/min',
  numeric: true,
  sortable: true,
  width: width,
  value: (Pump p) => p.flow,
  format: (Pump p) => p.flow == null ? '--' : kkFixed(p.flow!, digits: 3),
);

/// Three columns with known widths: 80, flex, 96.
List<KkTableColumn<Pump>> basicColumns() => <KkTableColumn<Pump>>[idColumn(), nameColumn(), flowColumn()];

Finder byRuntimeType(String name) => find.byWidgetPredicate((Widget w) => w.runtimeType.toString() == name);

/// The render object of the table's frame (inside the 1px border).
RenderBox frameOf(WidgetTester tester) => tester.renderObject<RenderBox>(byRuntimeType('KkTableFrame'));

/// The rectangle of the whole table (its border box).
Rect tableRect(WidgetTester tester) =>
    tester.getRect(find.byWidgetPredicate((Widget w) => w.runtimeType.toString().startsWith('KkDataTable<')));

/// The rows of cells that are mounted, top to bottom: the header first, then
/// body rows (and the summary row last when there is one).
List<RenderBox> cellRows(WidgetTester tester) {
  final List<RenderBox> rows = tester.renderObjectList<RenderBox>(byRuntimeType('KkTableCells')).toList();
  rows.sort((RenderBox a, RenderBox b) => a.localToGlobal(Offset.zero).dy.compareTo(b.localToGlobal(Offset.zero).dy));
  return rows;
}

Rect globalRect(RenderBox box) => box.localToGlobal(Offset.zero) & box.size;

/// The body row items that are mounted, in tree order.
Iterable<Element> rowItems(WidgetTester tester) => byRuntimeType('KkTableRowItem').evaluate();

/// The rectangle of the body row that shows [text].
Rect rowRectOf(WidgetTester tester, String text) =>
    tester.getRect(find.ancestor(of: find.text(text), matching: byRuntimeType('KkTableCells')).first);

/// The render object of the body row that shows [text].
RenderKkTableCells rowOf(WidgetTester tester, String text) => tester.renderObject<RenderKkTableCells>(
  find.ancestor(of: find.text(text), matching: byRuntimeType('KkTableCells')).first,
);

/// How the body row that shows [text] paints itself.
KkTableRowPaint lookOf(WidgetTester tester, String text) => rowOf(tester, text).look!;

/// A mouse that starts in the far corner.
Future<TestGesture> mouse(WidgetTester tester) async {
  final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(9999, 9999));
  addTearDown(gesture.removePointer);
  return gesture;
}

TextStyle styleOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!;

/// The texts matching [pattern] that are on screen, top to bottom.
List<String> textsInOrder(WidgetTester tester, RegExp pattern) {
  final List<(double, String)> found = <(double, String)>[];
  for (final Element e in find.byType(Text).evaluate()) {
    final String? data = (e.widget as Text).data;
    if (data == null || !pattern.hasMatch(data)) continue;
    final RenderBox box = e.renderObject! as RenderBox;
    found.add((box.localToGlobal(Offset.zero).dy, data));
  }
  found.sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return <String>[for (final (double, String) f in found) f.$2];
}

/// The ids of the pump rows on screen, top to bottom.
List<String> idsInOrder(WidgetTester tester) => textsInOrder(tester, RegExp(r'^[PR]-\d+$'));

/// Makes hover and focus highlights show without a real mouse or keyboard
/// mode switch, for the duration of the test.
void traditionalHighlights() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}

/// [what] inside the body row that shows [rowText].
Finder inRow(String rowText, Finder what) => find.descendant(
  of: find.ancestor(of: find.text(rowText), matching: byRuntimeType('KkTableCells')).first,
  matching: what,
);
