import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkSelectOption<String>> _options = <KkSelectOption<String>>[
  KkSelectOption<String>(value: 'a', label: 'Alpha', cjk: '甲', code: 'A-01'),
  KkSelectOption<String>(value: 'b', label: 'Bravo'),
  KkSelectOption<String>(value: 'c', label: 'Charlie', enabled: false),
  KkSelectOption<String>(value: 'd', label: 'Delta'),
  KkSelectOption<String>(value: 'k', label: 'Bunker'),
];

/// Holds the value of a select, the way an app would.
class _Host extends StatefulWidget {
  const _Host({this.initial, required this.builder});

  final String? initial;
  final Widget Function(String? value, ValueChanged<String> onChanged) builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? value = widget.initial;
  final List<String> changes = <String>[];

  @override
  Widget build(BuildContext context) => widget.builder(value, (String v) {
    changes.add(v);
    setState(() => value = v);
  });
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {String? character}) async {
  await tester.sendKeyEvent(key, character: character);
  await tester.pump();
}

/// The label of the menu row drawn as highlighted.
String? _highlighted(WidgetTester tester) {
  const KkColors c = KkColors.standby;
  const Set<String> labels = <String>{'ALPHA', 'BRAVO', 'CHARLIE', 'DELTA', 'BUNKER'};
  for (final Element e in find.byType(KkBox).evaluate()) {
    final KkBox box = e.widget as KkBox;
    if (box.height == 32 && box.decoration?.fill == c.bg300) {
      final Finder text = find.descendant(of: find.byWidget(box), matching: find.byType(Text));
      for (final Text t in tester.widgetList<Text>(text)) {
        if (labels.contains(t.data)) return t.data;
      }
    }
  }
  return null;
}

void main() {
  setUpAll(loadKkFonts);
  setUp(KkInputModality.notePointer);

  group('KkSelect', () {
    testWidgets('empty: label, placeholder in faint ink, a 36px field', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkSelect<String>(
          options: _options,
          onChanged: (String v) {},
          cjk: '区画',
          en: 'sector',
          isRequired: true,
          placeholder: 'Choose a sector',
          support: 'ONE OF FIVE',
          width: 280,
        ),
        padding: const EdgeInsets.all(40),
      );
      expect(find.text('区画'), findsOneWidget);
      expect(find.text('SECTOR'), findsOneWidget);
      expect(find.text('REQ'), findsOneWidget);
      expect(find.text('ONE OF FIVE'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Choose a sector')).style!.color, KkColors.standby.inkFaint);
      expect(tester.getSize(find.byType(KkFieldBox)), const Size(280, 36));
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.signal);
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('a press opens the list under the field, as wide as the field', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _Host(
          initial: 'b',
          builder: (String? value, ValueChanged<String> onChanged) =>
              KkSelect<String>(options: _options, value: value, onChanged: onChanged, width: 280),
        ),
        padding: const EdgeInsets.all(40),
      );
      // The chosen option reads as authored in the field.
      expect(find.text('Bravo'), findsOneWidget);
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      final Rect field = tester.getRect(find.byType(KkFieldBox));
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      expect(menu.left, field.left);
      expect(menu.width, field.width);
      expect(menu.top, field.bottom + 4);
      // 2 top + 4 pad + 5 rows of 32 + 4 pad + 1 bottom.
      expect(menu.height, 2 + 4 + 5 * 32 + 4 + 1);
      // The field reads as focused while the list is open.
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).focused, isTrue);
      // Options are in capitals in the list; codes sit at the right; the
      // current one starts highlighted.
      expect(find.text('ALPHA'), findsOneWidget);
      expect(find.text('甲'), findsOneWidget);
      expect(find.text('A-01'), findsOneWidget);
      expect(tester.getTopRight(find.text('A-01')).dx, menu.right - 1 - 12);
      expect(_highlighted(tester), 'BRAVO');
    });

    testWidgets('choosing reports the value, closes the list and returns the focus', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(
          builder: (String? value, ValueChanged<String> onChanged) => KkSelect<String>(
            options: _options,
            value: value,
            onChanged: onChanged,
            placeholder: 'Choose',
            width: 280,
            focusNode: focus,
          ),
        ),
        padding: const EdgeInsets.all(40),
      );
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      await tester.tap(find.text('DELTA'));
      await tester.pump();
      await tester.pump();
      expect(_host(tester).changes, <String>['d']);
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(find.text('Delta'), findsOneWidget);
      expect(find.text('Choose'), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);

      // Choosing the current value again reports nothing.
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      await tester.tap(find.text('DELTA'));
      await tester.pump();
      expect(_host(tester).changes, <String>['d']);
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('a disabled option cannot be chosen', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _Host(
          builder: (String? value, ValueChanged<String> onChanged) =>
              KkSelect<String>(options: _options, value: value, onChanged: onChanged, width: 280),
        ),
        padding: const EdgeInsets.all(40),
      );
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      await tester.tap(find.text('CHARLIE'));
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      expect(find.byType(KkMenu<String>), findsOneWidget);
      expect(tester.widget<Text>(find.text('CHARLIE')).style!.color, KkColors.standby.inkFaint);
    });

    testWidgets('keyboard: arrows open, move past disabled options and wrap; Enter chooses', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(
          initial: 'b',
          builder: (String? value, ValueChanged<String> onChanged) =>
              KkSelect<String>(options: _options, value: value, onChanged: onChanged, width: 280, focusNode: focus),
        ),
        padding: const EdgeInsets.all(40),
      );
      focus.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      expect(_highlighted(tester), 'BRAVO');
      // Charlie is disabled: the highlight goes straight to Delta.
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'DELTA');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'BUNKER');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'ALPHA');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_highlighted(tester), 'BUNKER');
      await _key(tester, LogicalKeyboardKey.home);
      expect(_highlighted(tester), 'ALPHA');
      await _key(tester, LogicalKeyboardKey.end);
      expect(_highlighted(tester), 'BUNKER');
      // Nothing is chosen until Enter.
      expect(_host(tester).changes, isEmpty);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_host(tester).changes, <String>['k']);
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);

      // Arrow up opens too, on the current value.
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_highlighted(tester), 'BUNKER');
    });

    testWidgets('keyboard: Enter and Space open; Escape closes and changes nothing', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(
          initial: 'a',
          builder: (String? value, ValueChanged<String> onChanged) =>
              KkSelect<String>(options: _options, value: value, onChanged: onChanged, width: 280, focusNode: focus),
        ),
        padding: const EdgeInsets.all(40),
      );
      focus.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_highlighted(tester), 'BRAVO');
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(_host(tester).changes, isEmpty);
      expect(focus.hasPrimaryFocus, isTrue);

      await _key(tester, LogicalKeyboardKey.space, character: ' ');
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      // Typing in the open list moves the highlight. While letters are being
      // typed a space belongs to them; once the buffer has reset it chooses.
      await _key(tester, LogicalKeyboardKey.keyD, character: 'd');
      expect(_highlighted(tester), 'DELTA');
      await _key(tester, LogicalKeyboardKey.space, character: ' ');
      expect(_host(tester).changes, isEmpty);
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.space, character: ' ');
      await tester.pump();
      expect(_host(tester).changes, <String>['d']);
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('typing on the closed field chooses the next option that starts with the letters', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        _Host(
          builder: (String? value, ValueChanged<String> onChanged) =>
              KkSelect<String>(options: _options, value: value, onChanged: onChanged, width: 280, focusNode: focus),
        ),
        padding: const EdgeInsets.all(40),
      );
      focus.requestFocus();
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.keyB, character: 'b');
      expect(_host(tester).value, 'b');
      expect(find.byType(KkMenu<String>), findsNothing);
      // The buffer resets after 700ms; one letter then cycles through matches.
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.keyB, character: 'b');
      expect(_host(tester).value, 'k');
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.keyB, character: 'b');
      expect(_host(tester).value, 'b');
      // Letters typed quickly are taken together: "bu" is Bunker.
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.keyB, character: 'b');
      await _key(tester, LogicalKeyboardKey.keyU, character: 'u');
      expect(_host(tester).value, 'k');
      // A disabled option is never chosen; no match changes nothing.
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.keyC, character: 'c');
      expect(_host(tester).value, 'k');
      await tester.pump(const Duration(milliseconds: 800));
      await _key(tester, LogicalKeyboardKey.keyZ, character: 'z');
      expect(_host(tester).value, 'k');
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('Escape, a press outside and the controller close the list', (WidgetTester tester) async {
      final KkMenuController controller = KkMenuController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkSelect<String>(options: _options, value: 'a', onChanged: (String v) {}, width: 280, controller: controller),
        padding: const EdgeInsets.all(40),
      );
      controller.open();
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      controller.open();
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      controller.close();
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      // A second press on the field closes it as well.
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('initiallyOpen shows the list in the first frame', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkSelect<String>(options: _options, value: 'd', onChanged: (String v) {}, width: 280, initiallyOpen: true),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      expect(tester.getTopLeft(find.byType(KkMenu<String>)), const Offset(40, 80));
    });

    testWidgets('disabled, and with no onChanged: dashed, faint, does not open', (WidgetTester tester) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKk(
        tester,
        KkSelect<String>(
          options: _options,
          value: 'a',
          onChanged: (String v) {},
          enabled: false,
          width: 280,
          focusNode: focus,
          initiallyOpen: true,
        ),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).enabled, isFalse);
      expect(tester.widget<Text>(find.text('Alpha')).style!.color, KkColors.standby.inkFaint);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.inkFaint);
      await tester.tap(find.byType(KkFieldBox), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focus.hasFocus, isFalse);

      await pumpKk(
        tester,
        const KkSelect<String>(options: _options, value: 'a', width: 280),
        padding: const EdgeInsets.all(40),
      );
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).enabled, isFalse);
      await tester.tap(find.byType(KkFieldBox), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('turning it off while open closes the list', (WidgetTester tester) async {
      Widget select({required bool enabled}) =>
          KkSelect<String>(options: _options, value: 'a', onChanged: (String v) {}, width: 280, enabled: enabled);
      await pumpKk(tester, select(enabled: true), padding: const EdgeInsets.all(40));
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
      await pumpKk(tester, select(enabled: false), padding: const EdgeInsets.all(40));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error: alert border and chevron, message replaces the support line', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkSelect<String>(
          options: _options,
          onChanged: (String v) {},
          placeholder: 'Choose',
          support: 'ONE OF FIVE',
          error: 'A SECTOR IS REQUIRED',
          width: 280,
        ),
      );
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).error, isTrue);
      expect(find.text('A SECTOR IS REQUIRED'), findsOneWidget);
      expect(find.text('ONE OF FIVE'), findsNothing);
      expect(tester.widget<KkIcon>(find.byType(KkIcon)).color, KkColors.standby.alert);
    });

    testWidgets('sm and xs: 32 and 24px, as wide as their text; the list is at least as wide', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        KkRow(
          gap: 16,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkSelect<String>(
              key: const ValueKey<String>('sm'),
              options: _options,
              value: 'b',
              onChanged: (String v) {},
              size: KkSelectSize.sm,
            ),
            KkSelect<String>(
              key: const ValueKey<String>('xs'),
              options: _options,
              value: 'b',
              onChanged: (String v) {},
              size: KkSelectSize.xs,
            ),
            KkSelect<String>(
              key: const ValueKey<String>('fixed'),
              options: _options,
              value: 'b',
              onChanged: (String v) {},
              size: KkSelectSize.sm,
              width: 180,
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
      );
      final Size sm = tester.getSize(find.byKey(const ValueKey<String>('sm')));
      final Size xs = tester.getSize(find.byKey(const ValueKey<String>('xs')));
      expect(sm.height, 32);
      expect(xs.height, 24);
      // Text, gap, 12px chevron, padding and the 1px border on each side.
      final double smText = tester.getSize(find.text('Bravo').at(0)).width;
      final double xsText = tester.getSize(find.text('Bravo').at(1)).width;
      expect(sm.width, closeTo(1 + 12 + smText + 6 + 12 + 12 + 1, 0.01));
      expect(xs.width, closeTo(1 + 4 + xsText + 4 + 12 + 4 + 1, 0.01));
      expect(tester.getSize(find.byKey(const ValueKey<String>('fixed'))), const Size(180, 32));
      expect(find.byType(KkFieldBox), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('xs')));
      await tester.pump();
      final Rect trigger = tester.getRect(find.byKey(const ValueKey<String>('xs')));
      final Rect menu = tester.getRect(find.byType(KkMenu<String>));
      // The list sits on whole pixels, the trigger where its row put it.
      expect(menu.left, closeTo(trigger.left, 0.5));
      expect(menu.top, trigger.bottom + 4);
      expect(menu.width, greaterThanOrEqualTo(trigger.width - 0.001));
      // The widest row decides: the list is not squeezed to the trigger.
      expect(tester.getSize(find.text('A-01')).width, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('DELTA'));
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsNothing);
    });

    testWidgets('a long list scrolls inside menuMaxHeight and flips above near the bottom', (
      WidgetTester tester,
    ) async {
      final List<KkSelectOption<int>> many = <KkSelectOption<int>>[
        for (int i = 0; i < 40; i++) KkSelectOption<int>(value: i, label: 'Unit ${i.toString().padLeft(2, '0')}'),
      ];
      await pumpKk(
        tester,
        KkSelect<int>(options: many, value: 30, onChanged: (int v) {}, width: 280, menuMaxHeight: 200),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(40),
      );
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      await tester.pump();
      final Rect field = tester.getRect(find.byType(KkFieldBox));
      final Rect menu = tester.getRect(find.byType(KkMenu<int>));
      expect(menu.height, 200);
      expect(menu.bottom, field.top - 4);
      // The current option has been scrolled into view.
      final Rect current = tester.getRect(find.text('UNIT 30'));
      expect(current.top, greaterThanOrEqualTo(menu.top));
      expect(current.bottom, lessThanOrEqualTo(menu.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics: a button with the label and the chosen value', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkSelect<String>(options: _options, value: 'd', onChanged: (String v) {}, en: 'sector', width: 280),
      );
      final SemanticsNode node = tester.getSemantics(find.byType(KkPressable));
      expect(node.label, contains('sector'));
      expect(node.value, 'Delta');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('the mouse hovers the field; the wheel over the open list does not close it', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        KkSelect<String>(options: _options, value: 'a', onChanged: (String v) {}, width: 280),
        padding: const EdgeInsets.all(40),
      );
      // The test platform is a phone, where hover highlights stay off: show
      // them as a desktop does.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pump();
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(KkFieldBox)));
      await tester.pump();
      expect(tester.widget<KkFieldBox>(find.byType(KkFieldBox)).hovered, isTrue);
      await tester.tap(find.byType(KkFieldBox));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('DELTA')));
      await tester.pump();
      expect(_highlighted(tester), 'DELTA');
      await tester.sendEventToBinding(
        PointerScrollEvent(position: tester.getCenter(find.text('DELTA')), scrollDelta: const Offset(0, 20)),
      );
      await tester.pump();
      expect(find.byType(KkMenu<String>), findsOneWidget);
    });
  });
}
