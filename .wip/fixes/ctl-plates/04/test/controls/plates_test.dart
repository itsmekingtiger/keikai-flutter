import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';
import 'util.dart';

const Key _shot = ValueKey<String>('shot');

/// Reads what the repaint boundary with the key [_shot] painted, at one
/// device pixel per logical pixel: the result gives the colour at a point of
/// the screen.
Future<Color Function(Offset at)> _shoot(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  late ByteData bytes;
  late int width;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    width = image.width;
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  return (Offset at) {
    final Offset local = boundary.globalToLocal(at);
    // Bytes are red, green, blue, alpha.
    final int i = (local.dy.floor() * width + local.dx.floor()) * 4;
    return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  };
}

void main() {
  setUpAll(loadKkFonts);

  const KkColors c = KkColors.standby;

  group('a pinned badge keeps to its host', () {
    Rect plateRect(WidgetTester tester) => tester.getRect(find.byType(KkSurface).first);
    Rect badgeRect(WidgetTester tester) => tester.getRect(find.byType(KkBadge));

    /// Parents that hand a child more than its own size: a larger touch
    /// target, a minimum, a column and a row that stretch.
    final Map<String, Widget Function(Widget child)> parents = <String, Widget Function(Widget child)>{
      'a tight 48px box': (Widget child) => SizedBox(width: 48, height: 48, child: child),
      'a 48px minimum': (Widget child) => KkBox(minWidth: 48, minHeight: 48, child: child),
      'a 300px column': (Widget child) =>
          KkBox(width: 300, child: KkColumn(shrinkWrap: true, children: <Widget>[child])),
      'a column as wide as a button': (Widget child) => KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          KkButton(label: 'acknowledge', onPressed: () {}),
          child,
        ],
      ),
      'a stretching row 48px high': (Widget child) => KkBox(
        height: 48,
        child: KkRow(shrinkWrap: true, cross: KkCrossAlign.stretch, children: <Widget>[child]),
      ),
    };

    for (final MapEntry<String, Widget Function(Widget child)> parent in parents.entries) {
      testChecked('KkIconButton in ${parent.key}: the badge sits on the corner of the plate', (
        WidgetTester tester,
      ) async {
        const Key button = ValueKey<String>('button');
        Widget build(Widget? badge) => parent.value(
          KkIconButton(
            key: button,
            icon: KkIcons.bell,
            variant: KkIconButtonVariant.outline,
            badge: badge,
            onPressed: () {},
          ),
        );
        Rect plate() => tester.getRect(find.descendant(of: find.byKey(button), matching: find.byType(KkSurface)).first);

        await pumpKk(tester, build(null), padding: const EdgeInsets.all(40));
        final Rect plain = plate();

        await pumpKk(tester, build(const KkBadge(count: 7)), padding: const EdgeInsets.all(40));
        expect(plate(), plain, reason: 'a badge does not change the layout of the button');
        expect(tester.getRect(find.byKey(button)), plain);
        expect(badgeRect(tester).top, plain.top - 5);
        expect(badgeRect(tester).right, plain.right + 7);
      });
    }

    testChecked('KkBadgeAnchor is laid out as its child is, with the badge on the corner of the child', (
      WidgetTester tester,
    ) async {
      const Widget host = KkBox(key: ValueKey<String>('host'), width: 40, height: 20);
      final Map<String, Widget Function(Widget child)> around = <String, Widget Function(Widget child)>{
        ...parents,
        'a 200px box': (Widget child) => KkBox(width: 200, child: child),
      };
      for (final MapEntry<String, Widget Function(Widget child)> parent in around.entries) {
        await pumpKk(tester, parent.value(host), padding: const EdgeInsets.all(40));
        final Rect alone = tester.getRect(find.byKey(const ValueKey<String>('host')));

        await pumpKk(
          tester,
          parent.value(const KkBadgeAnchor(badge: KkBadge(count: 5), child: host)),
          padding: const EdgeInsets.all(40),
        );
        final Rect child = tester.getRect(find.byKey(const ValueKey<String>('host')));
        expect(child, alone, reason: 'in ${parent.key}');
        expect(tester.getRect(find.byType(KkBadgeAnchor)), child, reason: 'in ${parent.key}');
        expect(badgeRect(tester).top, child.top - 6, reason: 'in ${parent.key}');
        expect(badgeRect(tester).right, child.right + 8, reason: 'in ${parent.key}');
      }
    });

    testChecked('KkBadgeAnchor moves the badge with top and right, and takes its place from the child alone', (
      WidgetTester tester,
    ) async {
      Widget build({double top = -6, double right = -8, int count = 5}) => KkRow(
        shrinkWrap: true,
        children: <Widget>[
          KkBadgeAnchor(
            top: top,
            right: right,
            badge: KkBadge(count: count),
            child: const KkBox(key: ValueKey<String>('host'), width: 40, height: 20),
          ),
          const KkBox(key: ValueKey<String>('next'), width: 10, height: 10),
        ],
      );
      await pumpKk(tester, build(), padding: const EdgeInsets.all(40));
      expect(badgeRect(tester), const Rect.fromLTWH(40 + 40 + 8 - 16, 40 - 6, 16, 16));
      // The badge hangs over the edge without pushing the neighbour away.
      expect(tester.getRect(find.byKey(const ValueKey<String>('next'))).left, 80);

      await tester.pumpWidget(kkHarness(build(top: 2, right: 3), padding: const EdgeInsets.all(40)));
      expect(badgeRect(tester), const Rect.fromLTWH(40 + 40 - 3 - 16, 40 + 2, 16, 16));

      // A wider badge grows to the left: its right edge stays where it is.
      await tester.pumpWidget(kkHarness(build(count: 128), padding: const EdgeInsets.all(40)));
      expect(badgeRect(tester).right, 40 + 40 + 8);
      expect(badgeRect(tester).width, greaterThan(16));
      expect(tester.getRect(find.byKey(const ValueKey<String>('next'))).left, 80);
    });

    testWidgets('the badge is drawn over the button and leaves the press to it', (WidgetTester tester) async {
      int presses = 0;
      await pumpKk(
        tester,
        RepaintBoundary(
          key: _shot,
          child: KkBox(
            padding: const EdgeInsets.all(20),
            child: KkIconButton(
              icon: KkIcons.bell,
              variant: KkIconButtonVariant.filled,
              badge: const KkBadge.dot(),
              onPressed: () => presses++,
            ),
          ),
        ),
        padding: const EdgeInsets.all(20),
      );
      final Rect shared = plateRect(tester).intersect(badgeRect(tester));
      expect(shared.size, const Size(1, 3));
      final Color Function(Offset at) pixel = await _shoot(tester);
      expect(pixel(shared.center), c.alert, reason: 'the dot covers the corner of the signal plate');
      expect(pixel(shared.center + const Offset(-1, 0)), c.signal);

      await tester.tapAt(shared.center);
      expect(presses, 1);
    });
  });

  group('a pinned badge is no part of its host\'s baseline', () {
    testChecked('KkBadgeAnchor: showing the badge does not move the child in a baseline row', (
      WidgetTester tester,
    ) async {
      Widget build({required bool show}) => KkRow(
        shrinkWrap: true,
        cross: KkCrossAlign.baseline,
        children: <Widget>[
          const KkText.en('alarms', size: 15),
          KkBadgeAnchor(show: show, badge: const KkBadge(count: 3), child: const KkText.en('inbox', size: 15)),
        ],
      );
      await pumpKk(tester, build(show: false), padding: const EdgeInsets.all(40));
      expect(tester.getTopLeft(find.text('ALARMS')).dy, 40);
      expect(tester.getTopLeft(find.text('INBOX')).dy, 40);

      await tester.pumpWidget(kkHarness(build(show: true), padding: const EdgeInsets.all(40)));
      expect(find.byType(KkBadge), findsOneWidget);
      expect(tester.getTopLeft(find.text('ALARMS')).dy, 40);
      expect(tester.getTopLeft(find.text('INBOX')).dy, 40, reason: 'show hides the badge without changing the layout');
      expect(tester.getSize(find.byType(KkRow).first).height, 15);
    });

    testChecked('KkBadgeAnchor has the baseline of its child', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkRow(
          shrinkWrap: true,
          cross: KkCrossAlign.baseline,
          children: <Widget>[
            KkText.en('sector', size: 12),
            KkBadgeAnchor(
              badge: KkBadge(count: 3),
              child: KkBox(padding: EdgeInsets.only(top: 7), child: KkText.en('four', size: 24)),
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
      );
      final RenderBox anchor = tester.renderObject<RenderBox>(find.byType(KkBadgeAnchor));
      final RenderBox large = tester.renderObject<RenderBox>(find.text('FOUR'));
      final RenderBox small = tester.renderObject<RenderBox>(find.text('SECTOR'));
      expect(baselineOf(anchor), baselineOf(large)! + 7);
      // The two words stand on one line.
      expect(
        tester.getTopLeft(find.text('SECTOR')).dy + baselineOf(small)!,
        moreOrLessEquals(tester.getTopLeft(find.text('FOUR')).dy + baselineOf(large)!, epsilon: 0.001),
      );
      expect(tester.getTopLeft(find.byType(KkBadgeAnchor)).dy, 40);
    });

    testChecked('KkIconButton: a badge does not move the button in a baseline row', (WidgetTester tester) async {
      Widget build({required bool badge}) => KkRow(
        shrinkWrap: true,
        cross: KkCrossAlign.baseline,
        children: <Widget>[
          const KkText.en('alarms', size: 15),
          KkIconButton(icon: KkIcons.bell, badge: badge ? const KkBadge(count: 3) : null, onPressed: () {}),
        ],
      );
      await pumpKk(tester, build(badge: false), padding: const EdgeInsets.all(40));
      final Rect plain = tester.getRect(find.byType(KkIconButton));
      expect(plain.top, 40);

      await tester.pumpWidget(kkHarness(build(badge: true), padding: const EdgeInsets.all(40)));
      expect(find.byType(KkBadge), findsOneWidget);
      expect(tester.getRect(find.byType(KkIconButton)), plain);
      expect(tester.getTopLeft(find.text('ALARMS')).dy, 40);
    });
  });

  group('KkIconButton keeps its plate while a badge comes and goes', () {
    Widget button({required int trigger, required bool badge}) => KkIconButton(
      icon: KkIcons.refresh,
      spinTrigger: trigger,
      badge: badge ? const KkBadge(count: 3) : null,
      onPressed: () {},
      semanticLabel: 'Refresh',
    );

    /// How far round the icon is, in turns: 0, 0.25, 0.5 or 0.75 (-1 for
    /// anything between).
    double turned(WidgetTester tester) {
      final Transform t = tester.widget<Transform>(
        find.descendant(of: find.byType(KkIconButton), matching: find.byType(Transform)).first,
      );
      // rotationZ: sin is entry (1, 0), cos is entry (0, 0).
      final double sin = t.transform.entry(1, 0);
      final double cos = t.transform.entry(0, 0);
      if (sin.abs() < 1e-9) return cos > 0 ? 0 : 0.5;
      if (cos.abs() < 1e-9) return sin > 0 ? 0.25 : 0.75;
      return -1;
    }

    testWidgets('a trigger that changes as the badge goes still turns the icon once', (WidgetTester tester) async {
      await pumpKk(tester, button(trigger: 0, badge: true), motion: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(turned(tester), 0);

      // The press on a refresh button: the trigger moves on and the count of
      // what was waiting is cleared, in one build.
      await tester.pumpWidget(kkHarness(button(trigger: 1, badge: false), motion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(turned(tester), 0.25, reason: '160ms into the 0.6s turn the icon is a quarter round');
      await tester.pump(const Duration(milliseconds: 150));
      expect(turned(tester), 0.5);
      await tester.pump(const Duration(milliseconds: 300));
      expect(turned(tester), 0, reason: 'a full turn ends where it began');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a badge that comes or goes during a turn does not stop it', (WidgetTester tester) async {
      await pumpKk(tester, button(trigger: 0, badge: false), motion: true);
      await tester.pumpWidget(kkHarness(button(trigger: 1, badge: false), motion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(turned(tester), 0.25);

      await tester.pumpWidget(kkHarness(button(trigger: 1, badge: true), motion: true));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(KkBadge), findsOneWidget);
      expect(turned(tester), 0.25, reason: 'still 170ms into the turn');
      await tester.pump(const Duration(milliseconds: 140));
      expect(turned(tester), 0.5);

      await tester.pumpWidget(kkHarness(button(trigger: 1, badge: false), motion: true));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(KkBadge), findsNothing);
      expect(turned(tester), 0.5, reason: 'still 320ms into the turn');
      await tester.pump(const Duration(milliseconds: 300));
      expect(turned(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the plate is the same render object with and without a badge', (WidgetTester tester) async {
      RenderObject plate() => tester.renderObject(find.byType(KkSurface).first);

      await pumpKk(tester, button(trigger: 0, badge: false));
      final RenderObject plain = plate();
      await tester.pumpWidget(kkHarness(button(trigger: 0, badge: true)));
      expect(plate(), same(plain));
      await tester.pumpWidget(kkHarness(button(trigger: 0, badge: false)));
      expect(plate(), same(plain));
    });
  });

  group('KkButton stays a control while it is loading', () {
    /// A button that goes busy when it is pressed, under another button.
    Widget engage({required ValueNotifier<bool> loading, required FocusNode node, required VoidCallback onPressed}) {
      return ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (BuildContext context, bool busy, Widget? child) => KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            KkButton(label: 'first', onPressed: () {}),
            KkButton(
              label: 'engage',
              focusNode: node,
              loading: busy,
              onPressed: () {
                onPressed();
                loading.value = true;
              },
            ),
          ],
        ),
      );
    }

    Finder button() => find.widgetWithText(KkButton, 'ENGAGE');

    testWidgets('it keeps the keyboard focus and the ring when it goes busy and when it is done', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
      addTearDown(loading.dispose);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      int presses = 0;
      await pumpKk(tester, engage(loading: loading, node: node, onPressed: () => presses++));
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(presses, 1);
      expect(tester.widget<KkButton>(button()).loading, isTrue);
      expect(node.hasPrimaryFocus, isTrue, reason: 'the focus is on ${FocusManager.instance.primaryFocus}');
      expect(ringOf(tester, button()).visible, isTrue);

      // The keys are swallowed while it is busy.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(presses, 1);

      loading.value = false;
      await tester.pump();
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue, reason: 'the focus is on ${FocusManager.instance.primaryFocus}');
      expect(ringOf(tester, button()).visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 2);
    });

    testWidgets('it stays a Tab stop and takes autofocus', (WidgetTester tester) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkButton(label: 'first', autofocus: true, onPressed: () {}),
            KkButton(label: 'engage', focusNode: node, loading: true, onPressed: () {}),
          ],
        ),
      );
      await tester.pump();
      expect(node.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue);
      expect(ringOf(tester, button()).visible, isTrue);

      await pumpKk(tester, KkButton(label: 'engage', autofocus: true, loading: true, onLongPress: () {}));
      await tester.pump();
      expect(Focus.of(tester.element(find.text('ENGAGE'))).hasPrimaryFocus, isTrue);
    });

    testWidgets('the pointer changes nothing while it is busy', (WidgetTester tester) async {
      int presses = 0;
      int holds = 0;
      await pumpKk(
        tester,
        KkButton(label: 'engage', loading: true, onPressed: () => presses++, onLongPress: () => holds++),
        padding: const EdgeInsets.all(20),
      );
      final double rest = tester.getTopLeft(find.byType(KkSurface)).dy;
      await hoverOn(tester, find.byType(KkButton));
      expect(surfaceOf(tester, find.byType(KkButton)).fill, c.bg100, reason: 'no hover fill');

      final TestGesture press = await tester.startGesture(tester.getCenter(find.byType(KkButton)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.byType(KkSurface)).dy, rest, reason: 'no pressed shift');
      await press.up();
      await tester.pump();
      await tester.longPress(find.byType(KkButton));
      await tester.pump();
      expect(presses, 0);
      expect(holds, 0);
      expect(surfaceOf(tester, find.byType(KkButton)).edge, c.signal, reason: 'the live look');
    });

    testWidgets('screen readers hear a button that is busy, not one that is disabled', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ValueNotifier<bool> loading = ValueNotifier<bool>(false);
      addTearDown(loading.dispose);
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, engage(loading: loading, node: node, onPressed: () {}));
      node.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('ENGAGE')),
        isSemantics(
          label: 'ENGAGE',
          value: '',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocused: true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSemantics(find.text('ENGAGE')),
        isSemantics(
          label: 'ENGAGE',
          value: 'Loading',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
        ),
      );

      // The word can be put in the language of the app, and a semantic label
      // still replaces the visible text.
      await pumpKk(
        tester,
        KkButton(
          icon: KkIcons.download,
          loading: true,
          loadingLabel: '読込中',
          semanticLabel: 'Download log',
          onPressed: () {},
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Download log')),
        isSemantics(label: 'Download log', value: '読込中', isButton: true, hasEnabledState: true, isEnabled: true),
      );
      await pumpKk(tester, KkButton(icon: KkIcons.download, semanticLabel: 'Download log', onPressed: () {}));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Download log')),
        isSemantics(label: 'Download log', value: '', isButton: true, hasTapAction: true, isEnabled: true),
      );
      handle.dispose();
    });

    testWidgets('a disabled button is not busy', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await pumpKk(tester, KkButton(label: 'engage', focusNode: node, loading: true));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      expect(surfaceOf(tester, find.byType(KkButton)).edge, c.offline);
      expect(
        tester.getSemantics(find.text('ENGAGE')),
        isSemantics(label: 'ENGAGE', value: '', isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });
  });
}
