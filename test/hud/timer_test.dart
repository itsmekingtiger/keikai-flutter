import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../layout/layout_util.dart';
import '../support/harness.dart';

String _digits(WidgetTester tester) {
  final Text text = tester.widget(find.descendant(of: find.byType(KkBlink), matching: find.byType(Text)));
  return text.textSpan!.toPlainText();
}

/// The fill the bar is painted with, 0 to 1.
double _bar(WidgetTester tester) {
  final CustomPaint paint = tester.widget(
    find.descendant(of: find.byType(KkTimer), matching: find.byType(CustomPaint)),
  );
  // ignore: avoid_dynamic_calls
  return (paint.painter! as dynamic).value as double;
}

/// Lets [ms] milliseconds pass in 16ms frames, as a display does.
Future<void> _frames(WidgetTester tester, int ms) async {
  assert(ms % 16 == 0);
  for (int passed = 0; passed < ms; passed += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Owns the controller of the stopwatch it shows, and disposes it with itself.
class _OwnsController extends StatefulWidget {
  const _OwnsController();

  @override
  State<_OwnsController> createState() => _OwnsControllerState();
}

class _OwnsControllerState extends State<_OwnsController> {
  final KkTimerController _controller = KkTimerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (BuildContext context, Widget? child) => child!,
    child: KkTimer.stopwatch(controller: _controller),
  );
}

/// Counts down to [deadline] on [clock], as an app does with `deadline.difference(DateTime.now())`, and rebuilds
/// itself when the countdown reports that it has run out.
class _Deadline extends StatefulWidget {
  const _Deadline({required this.deadline, required this.clock, required this.onDone, this.controller});

  final Duration deadline;
  final Duration Function() clock;
  final VoidCallback onDone;
  final KkTimerController? controller;

  @override
  State<_Deadline> createState() => _DeadlineState();
}

class _DeadlineState extends State<_Deadline> {
  bool _expired = false;

  @override
  Widget build(BuildContext context) => KkTimer.countdown(
    from: widget.deadline - widget.clock(),
    controller: widget.controller,
    mode: _expired ? 'EXPIRED' : 'T-MINUS',
    onDone: () {
      widget.onDone();
      setState(() => _expired = true);
    },
  );
}

void main() {
  setUpAll(loadKkFonts);

  group('kkFormatTimer', () {
    ({String digits, String? centis}) f(Duration d, [KkTimerFormat format = KkTimerFormat.auto]) =>
        kkFormatTimer(d, format: format);

    test('zero', () {
      expect(f(Duration.zero), (digits: '00:00', centis: '.00'));
      expect(f(Duration.zero, KkTimerFormat.hours), (digits: '00:00:00', centis: null));
    });

    test('minutes, seconds and centiseconds below one hour', () {
      expect(f(const Duration(minutes: 4, seconds: 59, milliseconds: 820)), (digits: '04:59', centis: '.82'));
      expect(f(const Duration(milliseconds: 9)), (digits: '00:00', centis: '.00'));
      expect(f(const Duration(milliseconds: 10)), (digits: '00:00', centis: '.01'));
      expect(f(const Duration(minutes: 59, seconds: 59, milliseconds: 999)), (digits: '59:59', centis: '.99'));
    });

    test('hours from one hour on', () {
      expect(f(const Duration(hours: 1)), (digits: '01:00:00', centis: null));
      expect(f(const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456)), (
        digits: '01:02:03',
        centis: null,
      ));
      expect(f(const Duration(hours: 123, minutes: 4, seconds: 5)), (digits: '123:04:05', centis: null));
    });

    test('forced formats', () {
      expect(f(const Duration(hours: 2, minutes: 5, seconds: 7, milliseconds: 330), KkTimerFormat.minutes), (
        digits: '125:07',
        centis: '.33',
      ));
      expect(f(const Duration(seconds: 61), KkTimerFormat.hours), (digits: '00:01:01', centis: null));
    });

    test('negative times keep one sign in front; a rounding-size negative has none', () {
      expect(f(const Duration(seconds: -5, milliseconds: -250)), (digits: '-00:05', centis: '.25'));
      expect(f(const Duration(hours: -1, minutes: -30)), (digits: '-01:30:00', centis: null));
      expect(f(const Duration(milliseconds: -4)), (digits: '00:00', centis: '.00'));
    });

    test('a negative time that the hours format shows as zero has no sign', () {
      // The smallest unit written is the second: nothing is shown of -0.5s.
      expect(f(const Duration(milliseconds: -500), KkTimerFormat.hours), (digits: '00:00:00', centis: null));
      expect(f(const Duration(milliseconds: -999), KkTimerFormat.hours), (digits: '00:00:00', centis: null));
      expect(f(const Duration(milliseconds: -4), KkTimerFormat.hours), (digits: '00:00:00', centis: null));
      expect(f(const Duration(seconds: -1), KkTimerFormat.hours), (digits: '-00:00:01', centis: null));
      expect(f(const Duration(milliseconds: -1500), KkTimerFormat.hours), (digits: '-00:00:01', centis: null));
      // The centisecond formats show it, with its sign.
      expect(f(const Duration(milliseconds: -500)), (digits: '-00:00', centis: '.50'));
      expect(f(const Duration(milliseconds: -500), KkTimerFormat.minutes), (digits: '-00:00', centis: '.50'));
    });
  });

  testWidgets('a controlled timer shows its value; the box hugs the digits, 264px at least', (
    WidgetTester tester,
  ) async {
    await pumpKk(
      tester,
      const KkTimer(
        cjk: '残り時間',
        en: 't-minus',
        mode: 'COUNTDOWN',
        value: Duration(minutes: 4, seconds: 59, milliseconds: 820),
        progress: 0.62,
      ),
    );
    expect(_digits(tester), '04:59.82');
    expect(find.text('COUNTDOWN'), findsOneWidget);
    final Size size = tester.getSize(find.byType(KkTimer));
    expect(size.width, greaterThanOrEqualTo(264));
    expect(size.height, lessThan(140));
    // The digits are a 56px line.
    expect(tester.getSize(find.descendant(of: find.byType(KkBlink), matching: find.byType(Text))).height, 56);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 3)));
    expect(tester.getSize(find.byType(KkTimer)).width, 264);
    // No head row when there is nothing to put in it: 1 + 12 + 56 + 8 + 4 + 12 + 1.
    expect(tester.getSize(find.byType(KkTimer)).height, 94);
  });

  testWidgets('the head is its labels and the mode with one gap between each', (WidgetTester tester) async {
    // A timer that hugs a long head is as wide as cjk + 8 + en + 8 + mode inside its 16px padding and 1px border.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[
          KkTimer(
            cjk: '残り時間残り時間',
            en: 't-minus to automatic shutdown',
            mode: 'COUNTDOWN ARMED',
            value: Duration(seconds: 5),
          ),
        ],
      ),
    );
    Rect cjk = tester.getRect(find.byType(KkSqueeze));
    Rect en = tester.getRect(find.text('T-MINUS TO AUTOMATIC SHUTDOWN'));
    final Rect mode = tester.getRect(find.text('COUNTDOWN ARMED'));
    expect(en.left - cjk.right, closeTo(8, 0.01));
    expect(mode.left - en.right, closeTo(8, 0.01));
    expect(tester.getSize(find.byType(KkTimer)).width, greaterThan(264));
    expect(
      tester.getSize(find.byType(KkTimer)).width,
      closeTo(1 + 16 + cjk.width + 8 + en.width + 8 + mode.width + 16 + 1, 0.01),
    );

    // Without a mode nothing follows the labels, not even a gap.
    await pumpKk(
      tester,
      const KkWrap(
        children: <Widget>[
          KkTimer(cjk: '残り時間残り時間', en: 't-minus to automatic shutdown sequence', value: Duration(seconds: 5)),
        ],
      ),
    );
    cjk = tester.getRect(find.byType(KkSqueeze));
    en = tester.getRect(find.text('T-MINUS TO AUTOMATIC SHUTDOWN SEQUENCE'));
    expect(tester.getSize(find.byType(KkTimer)).width, greaterThan(264));
    expect(tester.getSize(find.byType(KkTimer)).width, closeTo(1 + 16 + cjk.width + 8 + en.width + 16 + 1, 0.01));

    // With room to spare, and alone in the head, the mode sits at the right.
    await pumpKk(tester, const KkTimer(cjk: '保持', en: 'hold', mode: 'T-MINUS', value: Duration(seconds: 5)));
    expect(tester.getRect(find.byType(KkSqueeze)).left, 17);
    expect(tester.getRect(find.text('T-MINUS')).right, closeTo(264 - 17, 0.01));
    await pumpKk(tester, const KkTimer(mode: 'T-MINUS', value: Duration(seconds: 5)));
    expect(tester.getRect(find.text('T-MINUS')).right, closeTo(264 - 17, 0.01));
  });

  testChecked('with any mix of head parts it passes the render self-checks at any width', (WidgetTester tester) async {
    const List<Widget> timers = <Widget>[
      KkTimer(cjk: '残り時間', en: 't-minus', mode: 'COUNTDOWN', value: Duration(seconds: 5)),
      KkTimer(en: 't-minus', value: Duration(seconds: 5)),
      KkTimer(mode: 'COUNTDOWN', value: Duration(hours: 5)),
      KkTimer(value: Duration(seconds: 5)),
    ];
    // Hugging, side by side.
    await pumpKk(
      tester,
      const KkWrap(gap: 8, cross: KkCrossAlign.start, children: timers),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
    // Filling a column, down to widths where neither head nor digits fit.
    for (final double width in <double>[0, 40, 120, 264, 400]) {
      await pumpKk(
        tester,
        KkBox(
          width: width,
          child: const KkColumn(gap: 8, shrinkWrap: true, children: timers),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    // On a shared baseline, which measures each one without laying it out.
    await pumpKk(
      tester,
      const KkRow(cross: KkCrossAlign.baseline, gap: 8, children: timers),
      size: const Size(1400, 600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty label or mode is laid out like one that is not given', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // Nothing to put in the head: no head row, as with no labels at all.
    await pumpKk(tester, const KkTimer(value: Duration(seconds: 3), cjk: '', en: '', mode: ''));
    expect(tester.getSize(find.byType(KkTimer)), const Size(264, 94));

    // No indent before the label for a word that is not there.
    await pumpKk(tester, const KkTimer(value: Duration(seconds: 3), cjk: '', en: 'hold', mode: ''));
    expect(tester.getTopLeft(find.text('HOLD')).dx, 1 + 16);
    expect(tester.getSemantics(find.bySemanticsLabel('hold')), isSemantics(value: '00:03.00'));
    handle.dispose();
  });

  testWidgets('caution colours the border; critical adds the glow and blinks the digits', (WidgetTester tester) async {
    const KkColors c = KkColors.standby;
    KkDecoration frame() =>
        tester.widget<KkBox>(find.descendant(of: find.byType(KkTimer), matching: find.byType(KkBox)).first).decoration!;

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 90)));
    expect(frame().edges.top.color, c.line);
    expect(frame().glow, isNull);
    expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isFalse);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 90), level: KkLevel.caution));
    expect(frame().edges.top.color, c.caution);
    expect(frame().glow, isNull);

    await pumpKk(tester, const KkTimer(value: Duration(seconds: 9), level: KkLevel.critical));
    expect(frame().edges.top.color, c.alert);
    expect(frame().glow, c.glowAlert);
    expect(tester.widget<KkBlink>(find.byType(KkBlink)).enabled, isTrue);
  });

  testWidgets('critical digits blink: full for 0.6s, dim for 0.6s', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkTimer(value: Duration(seconds: 9), level: KkLevel.critical, boot: false),
      motion: true,
    );
    double opacity() =>
        tester.widget<Opacity>(find.descendant(of: find.byType(KkBlink), matching: find.byType(Opacity))).opacity;
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), 0.2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(), 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a countdown ticks by itself, changes level near the end and reports when done', (
    WidgetTester tester,
  ) async {
    int done = 0;
    await pumpKk(
      tester,
      KkTimer.countdown(
        from: const Duration(seconds: 3),
        cautionAt: const Duration(seconds: 2),
        criticalAt: const Duration(seconds: 1),
        onDone: () => done++,
      ),
    );
    KkDecoration frame() =>
        tester.widget<KkBox>(find.descendant(of: find.byType(KkTimer), matching: find.byType(KkBox)).first).decoration!;
    expect(_digits(tester), '00:03.00');
    expect(frame().edges.top.color, KkColors.standby.line);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:02.00');
    expect(frame().edges.top.color, KkColors.standby.caution);

    await tester.pump(const Duration(milliseconds: 1250));
    expect(_digits(tester), '00:00.75');
    expect(frame().edges.top.color, KkColors.standby.alert);
    expect(done, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    // It has stopped: more time changes nothing and does not call again.
    await tester.pump(const Duration(seconds: 5));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
  });

  testWidgets('a countdown that starts with nothing left reports done at once', (WidgetTester tester) async {
    int done = 0;
    await pumpKk(tester, KkTimer.countdown(from: Duration.zero, onDone: () => done++));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1, reason: 'once');

    // Given another duration with nothing in it, it is still the countdown that has run out.
    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: -5), onDone: () => done++));
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 1);

    // Given time to count, it counts and reports again.
    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: 2), onDone: () => done++));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_digits(tester), '00:00.50');
    expect(done, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(done, 2);

    // A running countdown that is given nothing to count.
    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: 5), onDone: () => done++));
    await tester.pump(const Duration(seconds: 1));
    expect(done, 2);
    await pumpKk(tester, KkTimer.countdown(from: Duration.zero, onDone: () => done++));
    expect(done, 3);
    await tester.pump(const Duration(seconds: 6));
    expect(done, 3);
  });

  testWidgets('a countdown to a deadline reports once when the deadline passes, however its parent rebuilds', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int done = 0;
    int notified = 0;
    Duration now = Duration.zero;
    await pumpKk(
      tester,
      _Deadline(deadline: const Duration(seconds: 1), clock: () => now, onDone: () => done++, controller: controller),
    );
    controller.addListener(() => notified++);
    for (int frame = 0; frame < 60; frame++) {
      now += const Duration(milliseconds: 16);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_digits(tester), '00:00.04');
    expect(done, 0);

    // The deadline passes. Reporting it rebuilds the parent, which hands the timer the time since the deadline:
    // a duration below zero, and another one with every build from here on.
    for (int frame = 0; frame < 60; frame++) {
      now += const Duration(milliseconds: 16);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_digits(tester), '00:00.00');
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(done, 1);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing is left to do');
    // Told that it ran out, and that the time counted is that of the new duration: nothing.
    expect(notified, 2);
    expect(controller.elapsed, Duration.zero);

    // Rebuilt for other reasons later, each time with another duration below zero.
    for (int i = 0; i < 5; i++) {
      now += const Duration(seconds: 1);
      tester.element(find.byType(_Deadline)).markNeedsBuild();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(done, 1);
    expect(notified, 2);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Started again by hand it has run out already. Reset first, it runs out anew.
    controller.start();
    expect(done, 1);
    controller.reset();
    controller.start();
    expect(done, 2);
    await tester.pump();
    await tester.pump();
    expect(done, 2);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a countdown to a deadline that had passed when it was built reports once', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int done = 0;
    int notified = 0;
    controller.addListener(() => notified++);
    // A clock that has moved on at every look, as DateTime.now() has.
    Duration now = const Duration(seconds: 5);
    await pumpKk(
      tester,
      _Deadline(
        deadline: Duration.zero,
        clock: () => now += const Duration(milliseconds: 1),
        onDone: () => done++,
        controller: controller,
      ),
    );
    expect(_digits(tester), '00:00.00');
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(done, 1);
    expect(notified, 1);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'the rebuild that onDone asked for reports nothing new');
    for (int frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(done, 1);
    expect(notified, 1);
  });

  testWidgets('a controller starts a countdown with nothing left into done, once until it is reset', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int done = 0;
    int notified = 0;
    controller.addListener(() => notified++);
    await pumpKk(
      tester,
      KkTimer.countdown(from: Duration.zero, controller: controller, autostart: false, onDone: () => done++),
    );
    expect(done, 0, reason: 'not started yet');
    expect(notified, 0);

    controller.start();
    expect(done, 1);
    expect(notified, 1);
    expect(controller.isRunning, isFalse);
    controller.start();
    expect(done, 1);
    expect(notified, 1);

    controller.reset();
    expect(notified, 2);
    controller.toggle();
    expect(done, 2);
    expect(notified, 3);

    // Another timer, which starts by itself: it tells its controller with the frame that shows it.
    final KkTimerController other = KkTimerController();
    addTearDown(other.dispose);
    int otherNotified = 0;
    other.addListener(() => otherNotified++);
    await pumpKk(
      tester,
      KkTimer.countdown(
        key: const ValueKey<String>('other'),
        from: Duration.zero,
        controller: other,
        onDone: () => done++,
      ),
    );
    expect(done, 3);
    expect(otherNotified, 1);
    expect(notified, 3, reason: 'the first timer had nothing to tell when it left');
  });

  testWidgets('with motion off the bar of a countdown is the time left, not the whole seconds left', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, const KkTimer.countdown(from: Duration(seconds: 2)));
    expect(_bar(tester), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:01.50');
    expect(_bar(tester), 0.75);
    await tester.pump(const Duration(milliseconds: 1250));
    expect(_digits(tester), '00:00.25');
    expect(_bar(tester), 0.125);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_digits(tester), '00:00.00');
    expect(_bar(tester), 0);
  });

  testWidgets('with motion on the bar of a running countdown makes nine equal jumps a second and then rests', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, const KkTimer.countdown(from: Duration(seconds: 3), boot: false), motion: true);
    expect(_bar(tester), 1);
    final List<int> jumps = <int>[];
    double last = 1;
    for (int ms = 16; ms <= 3008; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      final double bar = _bar(tester);
      if (bar != last) {
        // Every jump is a ninth of what one second is of the bar.
        expect(last - bar, closeTo(1 / 27, 1e-9), reason: '${ms}ms');
        jumps.add(ms);
        last = bar;
      }
      // A move sets out with the first frame that is no more than half a second before a whole second, and makes
      // its first jump four frames later. Just before that the bar is 0.56s behind the time, and it is never
      // further from it. It gets to the whole second a frame or two before the time does.
      final double left = ms >= 3000 ? 0 : (3000 - ms) / 3000;
      expect(bar - left, lessThan(0.57 / 3), reason: '${ms}ms');
      expect(left - bar, lessThan(0.04 / 3), reason: '${ms}ms');
    }
    // Nine jumps for each of the three seconds, all of them in the half second before the whole second. The bar is
    // on the whole second before the time is, empty at the end, and rests for the half second after it.
    expect(jumps, hasLength(27));
    for (int second = 0; second < 3; second++) {
      final List<int> move = jumps.sublist(second * 9, second * 9 + 9);
      expect(move.first, greaterThan(second * 1000 + 500), reason: '$move');
      expect(move.last, lessThan(second * 1000 + 1000), reason: '$move');
    }
    expect(_digits(tester), '00:00.00');
    expect(_bar(tester), 0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'nothing is left to move');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the bar sets out for a whole second with the frame that is half a second before it', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, const KkTimer.countdown(from: Duration(seconds: 3), boot: false), motion: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:02.50');
    expect(_bar(tester), 1);
    // The transition lasts 0.45s: its nine steps are done with a twentieth of a second to spare.
    await tester.pump(const Duration(milliseconds: 449));
    expect(_bar(tester), closeTo(2 / 3 + 1 / 27, 1e-9));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_digits(tester), '00:02.05');
    expect(_bar(tester), closeTo(2 / 3, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a countdown that does not start on a whole second starts with a full bar', (WidgetTester tester) async {
    await pumpKk(tester, const KkTimer.countdown(from: Duration(milliseconds: 2400), boot: false), motion: true);
    expect(_bar(tester), 1);
    // Its first whole second is less than half a second away, so the bar sets out for it at once.
    double last = 1;
    for (int ms = 16; ms <= 480; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_bar(tester), lessThanOrEqualTo(last), reason: '${ms}ms');
      last = _bar(tester);
    }
    expect(_digits(tester), '00:01.92');
    expect(_bar(tester), closeTo(2 / 2.4, 1e-9));
    // From there on it moves as any other: for the one second when 1.5s are left, and so on.
    await _frames(tester, 416);
    expect(_digits(tester), '00:01.50');
    expect(_bar(tester), closeTo(2 / 2.4, 1e-9));
    await _frames(tester, 480);
    expect(_digits(tester), '00:01.02');
    expect(_bar(tester), closeTo(1 / 2.4, 1e-9));
    await _frames(tester, 512);
    expect(_digits(tester), '00:00.51');
    expect(_bar(tester), closeTo(1 / 2.4, 1e-9));
    await _frames(tester, 480);
    expect(_digits(tester), '00:00.03');
    expect(_bar(tester), 0);
    await _frames(tester, 32);
    expect(_digits(tester), '00:00.00');
    expect(_bar(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a countdown that is given the time to a deadline with every frame keeps its bar full', (
    WidgetTester tester,
  ) async {
    int done = 0;
    Duration now = Duration.zero;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkTimer.countdown(from: const Duration(milliseconds: 2400) - now, boot: false, onDone: () => done++);
        },
      ),
      motion: true,
    );
    // Every build starts a countdown that has all of its time left, however near its next whole second is.
    for (int ms = 16; ms < 2400; ms += 16) {
      rebuild(() => now = Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_bar(tester), 1, reason: '${ms}ms');
    }
    expect(_digits(tester), '00:00.01');
    expect(done, 0);

    // The deadline passes: the countdown reports that once and its bar steps down to nothing.
    for (int ms = 2400; ms <= 2864; ms += 16) {
      rebuild(() => now = Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_digits(tester), '00:00.00');
    expect(_bar(tester), 0);
    expect(done, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with motion on the bar of a stopped countdown is the time left, and resuming does not move it back', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    Widget timer() => KkTimer.countdown(from: const Duration(seconds: 10), controller: controller, boot: false);
    await pumpKk(tester, timer(), motion: true);
    await _frames(tester, 3296);
    // Running, the bar is on the whole second nearest to the 6.7s that are left.
    expect(_digits(tester), '00:06.70');
    expect(_bar(tester), closeTo(0.7, 1e-9));

    // Stopped on its way to the next whole second, it steps on to the time left and stays there.
    await _frames(tester, 400);
    expect(_digits(tester), '00:06.30');
    expect(_bar(tester), inExclusiveRange(0.6304, 0.7));
    controller.stop();
    await tester.pump();
    await _frames(tester, 464);
    expect(_bar(tester), closeTo(0.6304, 1e-9));
    await tester.pump(const Duration(seconds: 2));
    expect(_digits(tester), '00:06.30');
    expect(_bar(tester), closeTo(0.6304, 1e-9));

    // Started again, it goes on to the six seconds that are nearest.
    controller.start();
    await tester.pump();
    expect(_bar(tester), closeTo(0.6304, 1e-9));
    await _frames(tester, 480);
    expect(_digits(tester), '00:05.82');
    expect(_bar(tester), closeTo(0.6, 1e-9));
    controller.stop();
    await tester.pump();
    await _frames(tester, 464);
    expect(_bar(tester), closeTo(0.5824, 1e-9));

    // Started again from 5.82s, it does not go back up to the six seconds it has left behind. It waits where it is
    // until the five are half a second away.
    controller.start();
    await tester.pump();
    for (int ms = 16; ms <= 320; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_bar(tester), closeTo(0.5824, 1e-9), reason: '${ms}ms');
    }
    expect(_digits(tester), '00:05.50');
    double last = _bar(tester);
    for (int ms = 16; ms <= 480; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_bar(tester), lessThanOrEqualTo(last), reason: '${ms}ms');
      last = _bar(tester);
    }
    expect(_digits(tester), '00:05.02');
    expect(_bar(tester), closeTo(0.5, 1e-9));

    // With motion switched off the bar is the time left at once, and with every frame after that.
    await pumpKk(tester, timer());
    expect(_bar(tester), closeTo(0.5024, 1e-9));
    await tester.pump(const Duration(milliseconds: 80));
    expect(_digits(tester), '00:04.94');
    expect(_bar(tester), closeTo(0.4944, 1e-9));

    // Reset, it is full again.
    controller.reset();
    await tester.pump();
    expect(_bar(tester), 1);
  });

  testWidgets('the bar of a controlled timer follows a progress that changes with every frame', (
    WidgetTester tester,
  ) async {
    Duration left = const Duration(seconds: 10);
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return KkTimer(value: left, progress: left.inMilliseconds / 10000, boot: false);
        },
      ),
      motion: true,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_bar(tester), 1);
    // The app counts down itself and rebuilds the timer with each 16ms frame.
    for (int frame = 1; frame <= 300; frame++) {
      rebuild(() => left = Duration(milliseconds: 10000 - frame * 16));
      await tester.pump(const Duration(milliseconds: 16));
      final double progress = left.inMilliseconds / 10000;
      expect(_bar(tester), greaterThanOrEqualTo(progress - 1e-9), reason: 'frame $frame');
      expect(_bar(tester) - progress, lessThan(0.65 / 10), reason: 'frame $frame');
    }
    expect(_digits(tester), '00:05.20');
    expect(_bar(tester), lessThan(0.6));
    await tester.pump(const Duration(milliseconds: 450));
    expect(_bar(tester), closeTo(0.52, 1e-9));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a controller starts, stops and resets a stopwatch', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int notified = 0;
    controller.addListener(() => notified++);
    await pumpKk(tester, KkTimer.stopwatch(controller: controller, autostart: false));
    expect(controller.isRunning, isFalse);
    expect(_digits(tester), '00:00.00');
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:00.00');

    controller.start();
    expect(controller.isRunning, isTrue);
    expect(notified, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_digits(tester), '00:01.50');
    expect(controller.elapsed, const Duration(milliseconds: 1500));

    controller.stop();
    expect(controller.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(_digits(tester), '00:01.50', reason: 'stopped time is kept');

    controller.toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:02.00', reason: 'resuming adds to the banked time');

    controller.reset();
    await tester.pump();
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, Duration.zero);
    expect(_digits(tester), '00:00.00');
    // start, stop, toggle (start), reset.
    expect(notified, 4);

    // A controller with no timer attached is inert.
    final KkTimerController loose = KkTimerController();
    addTearDown(loose.dispose);
    loose
      ..start()
      ..stop()
      ..reset();
    expect(loose.isRunning, isFalse);
    expect(loose.elapsed, Duration.zero);
  });

  testWidgets('a countdown keeps time under a page that covers it and reports done there', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int done = 0;
    int notified = 0;
    await pumpKk(
      tester,
      KkTimer.countdown(from: const Duration(seconds: 5), controller: controller, onDone: () => done++),
    );
    controller.addListener(() => notified++);
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:04.00');

    // Another page covers the timer's. Tickers under it are silent from here on.
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.push(KkPageRoute<void>(builder: (BuildContext context) => const KkText.en('another page')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkTimer), findsNothing);
    expect(find.byType(KkTimer, skipOffstage: false), findsOneWidget);

    // The time is counted all the same, a tenth of a second at a time.
    await tester.pump(const Duration(milliseconds: 3900));
    expect(done, 0);
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(4800, 4900));
    await tester.pump(const Duration(milliseconds: 200));
    expect(done, 1, reason: 'when the time is up, not when the page comes back');
    expect(notified, 1);
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, const Duration(seconds: 5));

    await tester.pump(const Duration(seconds: 6));
    navigator.pop();
    await tester.pump();
    await tester.pump();
    expect(_digits(tester), '00:00.00');
    expect(done, 1);
    expect(notified, 1);
  });

  testWidgets('a stopwatch keeps time while tickers are disabled around it', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    bool enabled = true;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(
            enabled: enabled,
            child: KkTimer.stopwatch(controller: controller),
          );
        },
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:01.00');

    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5050));
    // No frame reports the time now, so the digits stand still, but the time is counted.
    expect(_digits(tester), '00:01.00');
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(5950, 6050));

    // Stopped there, the timer keeps what was counted there.
    controller.stop();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(5950, 6050));
    controller.start();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(6950, 7050));

    // Back on the frame clock the count goes on from there.
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.elapsed.inMilliseconds, inInclusiveRange(7450, 7550));
    expect(_digits(tester), startsWith('00:07.5'));
  });

  testWidgets('time under disabled tickers is exact once frames report it again', (WidgetTester tester) async {
    bool enabled = true;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(enabled: enabled, child: const KkTimer.stopwatch());
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1230));
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5040));
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 1.23s shown, 5.04s hidden, 0.1s shown: nothing is rounded to the tenths counted while hidden.
    expect(_digits(tester), '00:06.37');
  });

  testWidgets('a countdown built under disabled tickers counts from its first frame, once', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    bool enabled = false;
    int done = 0;
    late StateSetter rebuild;
    await pumpKk(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          rebuild = setState;
          return TickerMode(
            enabled: enabled,
            child: KkTimer.countdown(from: const Duration(seconds: 3), controller: controller, onDone: () => done++),
          );
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 1040));
    expect(controller.elapsed, const Duration(seconds: 1));

    // The frame clock takes over with the whole 1.04s, not on top of the second counted so far.
    rebuild(() => enabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.elapsed, const Duration(milliseconds: 1540));
    expect(_digits(tester), '00:01.46');

    // Hidden again, it runs out there.
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(done, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(done, 1);
    expect(controller.isRunning, isFalse);
    expect(_digits(tester), '00:00.00');
  });

  testWidgets('a controller tells its listeners when the timer starts by itself', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    int notified = 0;
    controller.addListener(() => notified++);
    // The label is built before the timer below it attaches and starts.
    await pumpKk(
      tester,
      KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? _) => KkText.en(controller.isRunning ? 'running' : 'stopped'),
          ),
          KkTimer.stopwatch(controller: controller),
        ],
      ),
    );
    expect(controller.isRunning, isTrue);
    expect(notified, 1);
    expect(find.text('RUNNING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(notified, 1, reason: 'not on every tick');

    // A timer that does not start by itself changes nothing, so it tells nothing.
    final KkTimerController idle = KkTimerController();
    addTearDown(idle.dispose);
    int idleNotified = 0;
    idle.addListener(() => idleNotified++);
    await pumpKk(tester, KkTimer.stopwatch(controller: idle, autostart: false));
    expect(idleNotified, 0);
  });

  testWidgets('a controller tells its listeners when the timer starts again with a new duration', (
    WidgetTester tester,
  ) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: 1), controller: controller));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(controller.isRunning, isFalse);
    int notified = 0;
    controller.addListener(() => notified++);

    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: 5), controller: controller));
    expect(controller.isRunning, isTrue);
    expect(notified, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_digits(tester), '00:04.50');
    expect(notified, 1);

    // Rebuilt with the same duration it goes on and tells nothing.
    await pumpKk(tester, KkTimer.countdown(from: const Duration(seconds: 5), controller: controller, en: 'hold'));
    expect(notified, 1);
  });

  testWidgets('a controller tells its listeners when its timer leaves the tree or takes another controller', (
    WidgetTester tester,
  ) async {
    final KkTimerController first = KkTimerController();
    final KkTimerController second = KkTimerController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await pumpKk(tester, KkTimer.stopwatch(controller: first));
    await tester.pump(const Duration(seconds: 1));
    int firstNotified = 0;
    int secondNotified = 0;
    first.addListener(() => firstNotified++);
    second.addListener(() => secondNotified++);

    // The running timer is handed to the second controller.
    await pumpKk(tester, KkTimer.stopwatch(controller: second));
    expect(first.isRunning, isFalse);
    expect(first.elapsed, Duration.zero);
    expect(firstNotified, 1);
    expect(second.isRunning, isTrue);
    expect(second.elapsed, const Duration(seconds: 1));
    expect(secondNotified, 1);

    // The timer is removed.
    await pumpKk(tester, const KkText.en('no timer'));
    expect(second.isRunning, isFalse);
    expect(secondNotified, 2);
    expect(firstNotified, 1);
  });

  testWidgets('a controller disposed together with its timer is left alone', (WidgetTester tester) async {
    await pumpKk(tester, const _OwnsController());
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '00:01.00');
    // The timer is disposed first and its owner, with the controller, right after it in the same frame.
    await pumpKk(tester, const KkText.en('no timer'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disposed stopwatch lets go of its controller and its ticker', (WidgetTester tester) async {
    final KkTimerController controller = KkTimerController();
    addTearDown(controller.dispose);
    await pumpKk(tester, KkTimer.stopwatch(controller: controller));
    expect(controller.isRunning, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(controller.isRunning, isFalse);
    controller.start();
    expect(controller.isRunning, isFalse);
  });

  testWidgets('odd input and tiny boxes do not throw', (WidgetTester tester) async {
    await pumpKk(
      tester,
      const KkBox(
        width: 20,
        height: 10,
        child: KkTimer(cjk: '残り時間', en: 't-minus', mode: 'COUNTDOWN', value: Duration(hours: 99), progress: 7),
      ),
    );
    expect(tester.takeException(), isNull);
    await pumpKk(tester, const KkTimer(value: Duration(seconds: -5), progress: double.nan));
    expect(tester.takeException(), isNull);
    expect(_digits(tester), '-00:05.00');
    await pumpKk(tester, const KkTimer.countdown(from: Duration.zero));
    expect(tester.takeException(), isNull);
    expect(_digits(tester), '00:00.00');
  });
}
