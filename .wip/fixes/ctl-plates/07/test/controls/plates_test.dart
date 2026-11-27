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

/// Tells [onCreated] each time its State is created.
class _Probe extends StatefulWidget {
  const _Probe({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) => const KkText('T-00:42');
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

  group('KkButton keeps its content while loading comes and goes', () {
    /// The painter of the busy bar, if the button shows one.
    CustomPainter? busyBar(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byType(KkButton), matching: find.byType(CustomPaint)))
        .map((CustomPaint paint) => paint.foregroundPainter)
        .nonNulls
        .firstOrNull;

    testWidgets('a child keeps its State when the button goes busy and when it is done', (WidgetTester tester) async {
      int created = 0;
      Widget build({required bool loading}) => KkButton(
        loading: loading,
        onPressed: () {},
        child: _Probe(onCreated: () => created++),
      );
      await pumpKk(tester, build(loading: false));
      expect(created, 1);
      expect(busyBar(tester), isNull);
      final State<StatefulWidget> state = tester.state(find.byType(_Probe));

      await tester.pumpWidget(kkHarness(build(loading: true)));
      expect(busyBar(tester), isNotNull);
      expect(created, 1, reason: 'the State of the child was created again when the button went busy');
      await tester.pumpWidget(kkHarness(build(loading: false)));
      expect(busyBar(tester), isNull);
      expect(created, 1, reason: 'the State of the child was created again when the button was done');
      expect(tester.state(find.byType(_Probe)), same(state));
    });

    testWidgets('the label is the same render object before, during and after', (WidgetTester tester) async {
      Widget build({required bool loading}) =>
          KkButton(label: 'engage', cjk: '起動', icon: KkIcons.power, loading: loading, onPressed: () {});
      await pumpKk(tester, build(loading: false), motion: true);
      final RenderObject label = tester.renderObject(find.text('ENGAGE'));
      final Rect rect = tester.getRect(find.byType(KkButton));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing runs in a button that is not busy');

      await tester.pumpWidget(kkHarness(build(loading: true), motion: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.renderObject(find.text('ENGAGE')), same(label));
      expect(tester.getRect(find.byType(KkButton)), rect);
      expect(busyBar(tester), isNotNull);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the bar scans');

      await tester.pumpWidget(kkHarness(build(loading: false), motion: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.renderObject(find.text('ENGAGE')), same(label));
      expect(busyBar(tester), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('a plate as wide as its text ends on a whole pixel', () {
    // Text is never a whole number of pixels wide: these would be 105.56,
    // 61.07, 134.26, 103.51, 50.4, 24.8, 75.8, 144.74, 75.58 and 138.54.
    final Map<String, Widget> plates = <String, Widget>{
      'a status tag': const KkStatusTag.status(KkLevel.critical),
      'a plain tag': const KkStatusTag('standby'),
      'a large tag': const KkStatusTag.status(KkLevel.nominal, size: KkStatusTagSize.lg),
      'a solid tag': const KkStatusTag.status(KkLevel.caution, variant: KkStatusTagVariant.solid),
      'a key cap': const KkKbd('CTRL+K'),
      'a short key cap': const KkKbd('F5'),
      'a button': KkButton(label: 'engage', onPressed: () {}),
      'a button with a cjk word': KkButton(label: 'acknowledge', cjk: '確認', onPressed: () {}),
      'a small button with an icon': KkButton(
        label: 'filter',
        icon: KkIcons.filter,
        size: KkButtonSize.sm,
        onPressed: () {},
      ),
      'an extended fab': KkFab.extended(label: 'new report', icon: KkIcons.plus, onPressed: () {}),
    };

    /// [plate] with its left edge on x = 8, in a boundary that [_shoot] reads.
    Widget specimen(Widget plate) => RepaintBoundary(
      key: _shot,
      child: KkBox(
        width: 400,
        height: 80,
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(8),
        child: plate,
      ),
    );

    for (final MapEntry<String, Widget> plate in plates.entries) {
      testChecked('${plate.key}: the right edge is one solid column of pixels, like the left', (
        WidgetTester tester,
      ) async {
        await pumpKk(tester, specimen(plate.value));
        final Rect rect = tester.getRect(find.byWidget(plate.value));
        expect(rect.left, 8);

        final Color Function(Offset at) pixel = await _shoot(tester);
        final double y = rect.center.dy;
        final Color edge = pixel(Offset(rect.left + 0.5, y));
        expect(edge.a, 1, reason: 'the left edge is solid');
        expect(pixel(Offset(rect.right - 0.5, y)), edge, reason: 'the last column is as solid as the first');
        expect(pixel(Offset(rect.right + 0.5, y)).a, 0, reason: 'nothing is smeared into the next column');
        expect(rect.width, rect.width.roundToDouble(), reason: 'a whole number of pixels');
      });
    }

    testChecked('a badge is rounded up as well where its digits are not whole pixels wide', (
      WidgetTester tester,
    ) async {
      // A digit of a badge is 6px wide. On a wall display, where every font
      // size is times 1.25, it is 7.5px, and `99+` with its padding 30.5px.
      await pumpKk(
        tester,
        specimen(const KkBadge(count: 128)),
        theme: const KeikaiThemeData(type: KkTypography(scale: 1.25)),
      );
      final Rect rect = tester.getRect(find.byType(KkBadge));
      expect(rect, const Rect.fromLTWH(8, 8, 31, 16));
      final Color Function(Offset at) pixel = await _shoot(tester);
      expect(pixel(Offset(rect.right - 0.5, rect.bottom - 2)), c.alert, reason: 'the last column is solid');
      expect(pixel(Offset(rect.right + 0.5, rect.bottom - 2)).a, 0);
      expect(tester.getRect(find.text('99+')).left, 12, reason: 'the digits keep their place');
    });

    testChecked('the content keeps its place and the plate grows by less than a pixel at the right', (
      WidgetTester tester,
    ) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            const KkStatusTag('standby'),
            const KkKbd('CTRL+K'),
            KkButton(label: 'engage', onPressed: () {}),
            KkButton(label: 'filter', icon: KkIcons.filter, onPressed: () {}),
            KkFab.extended(label: 'new report', onPressed: () {}),
          ],
        ),
      );
      // The gap between the plate and its content, at the left and at the right.
      (double, double) gaps(Type plate, Finder first, Finder last) {
        final Rect outer = tester.getRect(find.ancestor(of: first, matching: find.byType(plate)));
        return (tester.getRect(first).left - outer.left, outer.right - tester.getRect(last).right);
      }

      // 8px of padding inside the 1px outline.
      var (double left, double right) = gaps(KkStatusTag, find.text('STANDBY'), find.text('STANDBY'));
      expect(left, 9);
      expect(right, inInclusiveRange(9, 10));
      (left, right) = gaps(KkKbd, find.text('CTRL+K'), find.text('CTRL+K'));
      expect(left, 6);
      expect(right, inInclusiveRange(6, 7));
      (left, right) = gaps(KkButton, find.text('ENGAGE'), find.text('ENGAGE'));
      expect(left, 16);
      expect(right, inInclusiveRange(16, 17));
      (left, right) = gaps(KkButton, find.byType(KkIcon), find.text('FILTER'));
      expect(left, 12);
      expect(right, inInclusiveRange(16, 17));
      (left, right) = gaps(KkFab, find.text('NEW REPORT'), find.text('NEW REPORT'));
      expect(left, 16);
      expect(right, inInclusiveRange(24, 25));
    });

    testChecked('plates in a row all start on a whole pixel', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkRow(
          shrinkWrap: true,
          gap: 8,
          children: <Widget>[
            const KkStatusTag.status(KkLevel.critical),
            const KkStatusTag('standby'),
            const KkKbd('CTRL+K'),
            KkButton(label: 'engage', onPressed: () {}),
            const KkBadge(count: 7),
          ],
        ),
        padding: const EdgeInsets.all(8),
      );
      for (final Type plate in <Type>[KkStatusTag, KkKbd, KkButton, KkBadge]) {
        for (final Element element in find.byType(plate).evaluate()) {
          final Rect rect = tester.getRect(find.byElementPredicate((Element e) => e == element));
          expect(rect.left, rect.left.roundToDouble(), reason: '$plate at $rect');
          expect(rect.right, rect.right.roundToDouble(), reason: '$plate at $rect');
        }
      }
    });

    testChecked('a plate that is given its width takes it as it is', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            const KkBox(width: 120.4, child: KkStatusTag('standby')),
            KkBox(
              width: 120.4,
              child: KkButton(label: 'engage', onPressed: () {}),
            ),
            // Too narrow for the label: it is cut, and the plate is no wider.
            KkBox(
              width: 60.4,
              child: KkButton(label: 'acknowledge', onPressed: () {}),
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byType(KkStatusTag)).width, 120.4);
      expect(tester.getSize(find.byType(KkButton).at(0)).width, 120.4);
      expect(tester.getCenter(find.text('ENGAGE')).dx, moreOrLessEquals(60.2, epsilon: 0.01), reason: 'centred');
      expect(tester.getSize(find.byType(KkButton).at(1)).width, 60.4);
      expect(tester.takeException(), isNull);
    });

    testChecked('a parent that asks for the width of a plate gets room for all of its text', (
      WidgetTester tester,
    ) async {
      await pumpKk(tester, KkButton(label: 'acknowledge', cjk: '確認', onPressed: () {}));
      final double natural = tester.getSize(find.text('ACKNOWLEDGE')).width;
      final double plate = tester.getSize(find.byType(KkButton)).width;

      await pumpKk(
        tester,
        IntrinsicWidth(
          child: KkColumn(
            shrinkWrap: true,
            children: <Widget>[
              KkButton(label: 'acknowledge', cjk: '確認', onPressed: () {}),
              const KkBox(height: 4),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(KkButton)).width, plate);
      expect(tester.getSize(find.text('ACKNOWLEDGE')).width, natural, reason: 'the label is not cut short');
    });
  });

  group('text the user has enlarged stays inside a plate of fixed height', () {
    /// The plates of this family, under a system text size of [scale].
    Widget plates(double scale) => Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          gap: 8,
          children: <Widget>[
            const KkBadge(count: 8),
            const KkKbd('F5'),
            const KkStatusTag.status(KkLevel.critical),
            const KkStatusTag.status(KkLevel.critical, size: KkStatusTagSize.lg),
            KkButton(label: 'engage', cjk: '起動', size: KkButtonSize.sm, onPressed: () {}),
            KkButton(label: 'engage', cjk: '起動', onPressed: () {}),
            KkButton(label: 'engage', cjk: '起動', size: KkButtonSize.lg, onPressed: () {}),
            KkButton(onPressed: () {}, child: const KkText('T-00:42')),
            KkFab.extended(label: 'new', onPressed: () {}),
          ],
        ),
      ),
    );

    /// The height of the line of every text on screen, by what it says. A
    /// text that is cut off at the bottom fails the test.
    Map<String, double> lines(WidgetTester tester, {required String reason}) {
      final Map<String, double> heights = <String, double>{};
      for (final RenderParagraph text in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final String said = text.text.toPlainText();
        expect(
          text.size.height,
          greaterThanOrEqualTo(text.textSize.height - 0.001),
          reason: '"$said" is ${text.textSize.height} high and is given ${text.size.height}, $reason',
        );
        heights.putIfAbsent(said, () => text.textSize.height);
      }
      return heights;
    }

    void expectHeights(WidgetTester tester) {
      expect(tester.getSize(find.byType(KkBadge)).height, 16);
      expect(tester.getSize(find.byType(KkKbd)).height, 18);
      expect(tester.getSize(find.byType(KkStatusTag).at(0)).height, 22);
      expect(tester.getSize(find.byType(KkStatusTag).at(1)).height, 28);
      expect(tester.getSize(find.byType(KkButton).at(0)).height, 28);
      expect(tester.getSize(find.byType(KkButton).at(1)).height, 36);
      expect(tester.getSize(find.byType(KkButton).at(2)).height, 48);
      expect(tester.getSize(find.byType(KkFab)).height, 48);
    }

    // 2 is the largest text size on Android; the accessibility sizes of iOS
    // go up to 3.1.
    for (final double scale in <double>[1, 1.3, 1.6, 2, 3.1]) {
      testChecked('nothing is cut at $scale times the text size, and the plates keep their height', (
        WidgetTester tester,
      ) async {
        await pumpKk(tester, plates(scale));
        expect(tester.takeException(), isNull);
        lines(tester, reason: 'at $scale times the text size');
        expectHeights(tester);
      });
    }

    testWidgets('the text grows with the setting until it fills the plate', (WidgetTester tester) async {
      await pumpKk(tester, plates(1));
      final Map<String, double> normal = lines(tester, reason: 'at the normal text size');
      expect(normal['8'], 10);
      expect(normal['F5'], 10);
      expect(normal['CRITICAL'], 12);
      expect(normal['ENGAGE'], 13);

      await pumpKk(tester, plates(1.3));
      final Map<String, double> larger = lines(tester, reason: 'at 1.3 times the text size');
      for (final MapEntry<String, double> line in normal.entries) {
        expect(larger[line.key], greaterThan(line.value), reason: '"${line.key}" follows the setting');
      }

      // One line is as high as the plate is inside its border, and no higher.
      await pumpKk(tester, plates(3.1));
      final Map<String, double> largest = lines(tester, reason: 'at 3.1 times the text size');
      expect(largest['8'], 16);
      expect(largest['F5'], 15);
      expect(largest['CRITICAL'], 20);
      // A button is 28, 36 or 48 high with a 1px outline. The 14px cjk word of
      // the small one fills its 26px, and the 13px label beside it follows.
      expect(largest['起動'], 26);
      expect(largest['ENGAGE'], closeTo(26 * 13 / 14, 0.5));
      expect(largest['T-00:42'], 34);
      expect(largest['NEW'], 48);
    });

    testWidgets('the type scale of the theme counts as well', (WidgetTester tester) async {
      // Wall displays: every font size times 1.25. A badge then has room for
      // 16 / 12.5 times the text size.
      const KeikaiThemeData wall = KeikaiThemeData(type: KkTypography(scale: 1.25));
      await pumpKk(tester, plates(1), theme: wall);
      expect(lines(tester, reason: 'on a wall display')['8'], closeTo(12.5, 0.5));
      await pumpKk(tester, plates(1.5), theme: wall);
      final Map<String, double> large = lines(tester, reason: 'on a wall display at 1.5 times the text size');
      expect(large['8'], 16);
      expect(large['F5'], 15);
      expectHeights(tester);

      // A type scale too large for a plate on its own: the text is held to
      // the plate rather than cut.
      await pumpKk(tester, plates(1), theme: const KeikaiThemeData(type: KkTypography(scale: 2)));
      expect(lines(tester, reason: 'at twice the type scale')['8'], 16);
    });

    testWidgets('a plate without a media query above it is built as before', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkColumn(
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            const KkBadge(count: 8),
            const KkKbd('F5'),
            const KkStatusTag('standby'),
            KkButton(label: 'engage', onPressed: () {}),
            KkFab.extended(label: 'new', onPressed: () {}),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(lines(tester, reason: 'without a media query')['8'], 10);
    });
  });
}
