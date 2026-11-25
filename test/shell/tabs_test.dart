import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/shell/shell.dart';

import '../support/harness.dart';

const List<KkTab> _tabs = <KkTab>[
  KkTab(code: '01', cjk: '状況', en: 'situation'),
  KkTab(code: '02', cjk: '系統', en: 'systems'),
  KkTab(code: '03', cjk: '線図', en: 'diagram', enabled: false),
  KkTab(code: '04', cjk: '手順', en: 'procedure'),
];

/// Keeps the selected index like an app would.
class _Host extends StatefulWidget {
  const _Host({this.initial = 0, this.variant = KkTabsVariant.primary, this.autofocus = false, this.log});

  final int initial;
  final KkTabsVariant variant;
  final bool autofocus;
  final List<int>? log;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int index = widget.initial;

  @override
  Widget build(BuildContext context) {
    return KkColumn(
      shrinkWrap: true,
      children: <Widget>[
        KkTabs(
          tabs: _tabs,
          index: index,
          variant: widget.variant,
          autofocus: widget.autofocus,
          onChanged: (int i) {
            widget.log?.add(i);
            setState(() => index = i);
          },
        ),
        KkTabView(
          index: index,
          children: <Widget>[
            for (final KkTab tab in _tabs) KkBox(height: 100, child: KkText.body('BODY ${tab.code}')),
          ],
        ),
      ],
    );
  }
}

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  setUpAll(loadKkFonts);

  testWidgets('primary tabs are 40px high over a 1px line; secondary 32px', (WidgetTester tester) async {
    await pumpKk(tester, const _Host(), size: const Size(900, 400));
    expect(tester.getSize(find.byType(KkTabs)), const Size(900, 41));
    final Finder tab = find.ancestor(of: find.text('SITUATION'), matching: find.byType(KkPressable));
    expect(tester.getSize(tab).height, 40);

    await pumpKk(tester, const _Host(variant: KkTabsVariant.secondary), size: const Size(900, 400));
    expect(tester.getSize(find.byType(KkTabs)), const Size(900, 33));
    expect(
      tester.getSize(find.ancestor(of: find.text('SITUATION'), matching: find.byType(KkPressable))).height,
      32,
    );
    expect(tester.widget<Text>(find.text('SITUATION')).style!.fontSize, 11);
  });

  testWidgets('tapping a tab selects it; the selected tab lights its Latin title in signal', (
    WidgetTester tester,
  ) async {
    final List<int> log = <int>[];
    await pumpKk(tester, _Host(log: log), size: const Size(900, 400));
    final KkColors c = KkColors.standby;
    expect(tester.widget<Text>(find.text('SITUATION')).style!.color, c.signal);
    expect(tester.widget<Text>(find.text('状況')).style!.color, c.ink);
    expect(tester.widget<Text>(find.text('SYSTEMS')).style!.color, c.inkDim);
    expect(find.text('BODY 01'), findsOneWidget);

    await tester.tap(find.text('SYSTEMS'));
    await tester.pump();
    expect(log, <int>[1]);
    expect(tester.widget<Text>(find.text('SYSTEMS')).style!.color, c.signal);
    expect(tester.widget<Text>(find.text('SITUATION')).style!.color, c.inkDim);
    expect(find.text('BODY 02'), findsOneWidget);
    expect(find.text('BODY 01'), findsNothing);

    // Tapping the selected tab again reports nothing.
    await tester.tap(find.text('SYSTEMS'));
    await tester.pump();
    expect(log, <int>[1]);
  });

  testWidgets('a disabled tab is faint and ignores taps', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await pumpKk(tester, _Host(log: log), size: const Size(900, 400));
    expect(tester.widget<Text>(find.text('DIAGRAM')).style!.color, KkColors.standby.inkFaint);
    await tester.tap(find.text('DIAGRAM'));
    await tester.pump();
    expect(log, isEmpty);
  });

  testWidgets('with onChanged null every tab is disabled', (WidgetTester tester) async {
    await pumpKk(tester, const KkTabs(tabs: _tabs, index: 0), size: const Size(900, 400));
    expect(tester.widget<Text>(find.text('SYSTEMS')).style!.color, KkColors.standby.inkFaint);
    await tester.tap(find.text('SYSTEMS'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrow keys move to the next enabled tab and wrap; Home and End jump', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await pumpKk(tester, _Host(log: log, autofocus: true), size: const Size(900, 400));
    expect(_focused(), 'KkTab 0');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, <int>[1]);
    expect(_focused(), 'KkTab 1');

    // Tab 2 is disabled: Right skips it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, <int>[1, 3]);
    expect(_focused(), 'KkTab 3');

    // Past the end it wraps to the first.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(log, <int>[1, 3, 0]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(log, <int>[1, 3, 0, 3]);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(log.last, 0);
    expect(_focused(), 'KkTab 0');

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(log.last, 3);
    expect(_focused(), 'KkTab 3');
  });

  testWidgets('only the selected tab is a Tab stop', (WidgetTester tester) async {
    await pumpKk(
      tester,
      KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          const _Host(initial: 1),
          KkPressable(
            focusNode: FocusNode(debugLabel: 'after'),
            onPressed: () {},
            builder: (BuildContext context, KkStates s) => const KkBox(width: 40, height: 40),
          ),
        ],
      ),
      size: const Size(900, 400),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(), 'KkTab 1');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(), 'after');
  });

  testWidgets('Enter on a focused tab keeps it selected and Space activates too', (WidgetTester tester) async {
    final List<int> log = <int>[];
    await pumpKk(tester, _Host(log: log, autofocus: true), size: const Size(900, 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bar that is too narrow scrolls and keeps the selected tab in view', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 220, child: _Host(initial: 3)), size: const Size(900, 400));
    expect(tester.takeException(), isNull);
    final Rect bar = tester.getRect(find.byType(KkTabs));
    expect(bar.width, 220);
    final Rect selected = tester.getRect(
      find.ancestor(of: find.text('PROCEDURE'), matching: find.byType(KkPressable)),
    );
    expect(selected.left, greaterThanOrEqualTo(bar.left - 0.5));
    expect(selected.right, lessThanOrEqualTo(bar.right + 0.5));
    // No scrollbar is drawn for the tab strip.
    expect(find.descendant(of: find.byType(KkTabs), matching: find.byType(KkScrollbar)), findsNothing);
  });

  testWidgets('selecting an off-screen tab scrolls it into view', (WidgetTester tester) async {
    await pumpKk(tester, const KkBox(width: 220, child: _Host(autofocus: true)), size: const Size(900, 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.pump();
    final Rect bar = tester.getRect(find.byType(KkTabs));
    final Rect selected = tester.getRect(
      find.ancestor(of: find.text('PROCEDURE'), matching: find.byType(KkPressable)),
    );
    expect(selected.right, lessThanOrEqualTo(bar.right + 0.5));
    expect(selected.left, greaterThanOrEqualTo(bar.left - 0.5));
  });

  testWidgets('tabs report selection to assistive technology', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(tester, const _Host(initial: 1), size: const Size(900, 400));
    expect(
      tester.getSemantics(find.ancestor(of: find.text('SYSTEMS'), matching: find.byType(KkPressable)).first),
      isSemantics(isButton: true, isSelected: true, hasSelectedState: true, isEnabled: true, hasEnabledState: true),
    );
    expect(
      tester.getSemantics(find.ancestor(of: find.text('SITUATION'), matching: find.byType(KkPressable)).first),
      isSemantics(isButton: true, isSelected: false, hasSelectedState: true, isEnabled: true, hasEnabledState: true),
    );
    handle.dispose();
  });

  testWidgets('KkTabView shows the first body at once and wipes a new one in over 0.42s', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, const _Host(), size: const Size(900, 400), motion: true);
    // Let the page route's own wipe finish.
    await tester.pump(const Duration(milliseconds: 500));
    ClipRect clip() =>
        tester.widget<ClipRect>(find.descendant(of: find.byType(KkTabView), matching: find.byType(ClipRect)).first);
    expect(clip().clipBehavior, Clip.none);
    expect(find.text('BODY 01'), findsOneWidget);

    await tester.tap(find.text('SYSTEMS'));
    await tester.pump();
    expect(find.text('BODY 02'), findsOneWidget);
    expect(clip().clipBehavior, Clip.hardEdge);
    expect(clip().clipper!.getClip(const Size(700, 100)).width, 0);

    await tester.pump(const Duration(milliseconds: 210));
    final double half = clip().clipper!.getClip(const Size(700, 100)).width;
    expect(half, greaterThan(0));
    expect(half, lessThan(700));
    // Seven hard steps: the width is a multiple of a seventh.
    expect((half / 100).roundToDouble(), half / 100);

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    expect(clip().clipBehavior, Clip.none);
  });

  testWidgets('KkTabView can keep hidden bodies alive', (WidgetTester tester) async {
    int index = 0;
    late StateSetter set;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          set = setState;
          return KkTabView(
            index: index,
            maintainState: true,
            children: const <Widget>[_Counter(label: 'A'), _Counter(label: 'B')],
          );
        },
      ),
    );
    await tester.tap(find.text('A0'));
    await tester.pump();
    expect(find.text('A1'), findsOneWidget);
    set(() => index = 1);
    await tester.pump();
    expect(find.text('B0'), findsOneWidget);
    set(() => index = 0);
    await tester.pump();
    expect(find.text('A1'), findsOneWidget);
  });

  testWidgets('KkTabView tolerates an empty list and an index out of range', (WidgetTester tester) async {
    await pumpKk(tester, const KkTabView(index: 3, children: <Widget>[]));
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkTabView(index: 9, children: <Widget>[KkText('ONLY')]));
    expect(find.text('ONLY'), findsOneWidget);
    await pumpKk(tester, const KkTabs(tabs: <KkTab>[], index: 0));
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return KkPressable(
      onPressed: () => setState(() => n++),
      builder: (BuildContext context, KkStates s) => KkText('${widget.label}$n'),
    );
  }
}
