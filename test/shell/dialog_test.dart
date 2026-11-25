import 'dart:ui' show SemanticsRole;

import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// A page with one button that opens a dialog and records what it returned.
class _Opener extends StatefulWidget {
  const _Opener({this.dismissible = true, this.level, this.tall = false, required this.results});

  final bool dismissible;
  final KkLevel? level;
  final bool tall;
  final List<Object?> results;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  final FocusNode opener = FocusNode(debugLabel: 'opener');

  @override
  void dispose() {
    opener.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final String? result = await showKkDialog<String>(
      context: context,
      dismissible: widget.dismissible,
      builder: (BuildContext context) => KkDialog(
        code: 'DLG-07',
        cjk: '手順確認',
        en: 'confirm procedure',
        level: widget.level,
        hazard: widget.level == KkLevel.critical,
        actions: <Widget>[
          KkButton(
            label: 'cancel',
            variant: KkButtonVariant.ghost,
            focusNode: FocusNode(debugLabel: 'cancel'),
            onPressed: () => Navigator.of(context).pop('cancel'),
          ),
          KkButton(
            label: 'execute',
            variant: KkButtonVariant.primary,
            focusNode: FocusNode(debugLabel: 'execute'),
            onPressed: () => Navigator.of(context).pop('execute'),
          ),
        ],
        child: widget.tall
            ? KkColumn(shrinkWrap: true, children: <Widget>[for (int i = 0; i < 60; i++) KkText.body('LINE $i')])
            : const KkText.body('보조 펌프 B를 기동합니다.'),
      ),
    );
    widget.results.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return KkColumn(
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkButton(label: 'open', focusNode: opener, onPressed: _open),
        KkButton(
          label: 'other',
          focusNode: FocusNode(debugLabel: 'other'),
          onPressed: () {},
        ),
      ],
    );
  }
}

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pump();
  await tester.pump();
}

/// A list for results the test does not look at.
List<Object?> _sink() => <Object?>[];

void main() {
  setUpAll(loadKkFonts);

  testWidgets('opens centred, 520px wide, over the 78% scrim', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _Opener(results: results), size: const Size(1000, 700));
    expect(find.byType(KkDialog), findsNothing);
    await _open(tester);
    expect(find.byType(KkDialog), findsOneWidget);
    final Rect dialog = tester.getRect(find.byType(KkDialog));
    expect(dialog.width, 520);
    expect(dialog.center.dx, 500);
    expect(dialog.center.dy, closeTo(350, 0.5));
    final ModalBarrier barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, KkColors.standby.scrim);
    expect(barrier.dismissible, isTrue);
    expect(find.text('DLG-07'), findsOneWidget);
    expect(find.text('手順確認'), findsOneWidget);
    expect(find.text('CONFIRM PROCEDURE'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('head is 40px, body is padded by 16, actions are right-aligned', (WidgetTester tester) async {
    await pumpKk(tester, _Opener(results: _sink()), size: const Size(1000, 700));
    await _open(tester);
    final Rect dialog = tester.getRect(find.byType(KkDialog));
    final Rect code = tester.getRect(find.text('DLG-07'));
    final Rect body = tester.getRect(find.text('보조 펌프 B를 기동합니다.'));
    // 1px border, then a 40px head whose last pixel is the line under it.
    expect(code.center.dy, closeTo(dialog.top + 1 + 19.5, 0.5));
    expect(code.left, dialog.left + 1 + 12);
    expect(body.top, dialog.top + 1 + 40 + 16);
    expect(body.left, dialog.left + 1 + 16);
    final Rect execute = tester.getRect(find.byType(KkButton).last);
    expect(execute.right, dialog.right - 1 - 16);
    expect(execute.bottom, dialog.bottom - 1 - 12);
    final Rect cancel = tester.getRect(find.ancestor(of: find.text('CANCEL'), matching: find.byType(KkButton)));
    expect(execute.left - cancel.right, 8);
    final Rect close = tester.getRect(find.byType(KkIconButton));
    expect(close.right, dialog.right - 1 - 8);
    expect(close.size, const Size(32, 32));
  });

  testWidgets('the close button, an action, Escape and the scrim all close it', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _Opener(results: results), size: const Size(1000, 700));

    await _open(tester);
    await tester.tap(find.byType(KkIconButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
    expect(results, <Object?>[null]);

    await _open(tester);
    await tester.tap(find.text('EXECUTE'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
    expect(results, <Object?>[null, 'execute']);

    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
    expect(results.length, 3);

    await _open(tester);
    await tester.tapAt(const Offset(20, 680));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
    expect(results.length, 4);
  });

  testWidgets('a dialog that is not dismissible ignores Escape and the scrim', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _Opener(results: results, dismissible: false), size: const Size(1000, 700));
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(const Offset(20, 680));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsOneWidget);
    expect(tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).dismissible, isFalse);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump();
    expect(results, <Object?>['cancel']);
  });

  testWidgets('keyboard focus is trapped in the dialog and returns to the opener', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _Opener(results: results), size: const Size(1000, 700));
    // Reach the opener with the keyboard and press it.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focused(), 'opener');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsOneWidget);

    final Set<String?> visited = <String?>{};
    for (int i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      visited.add(_focused());
    }
    expect(visited, containsAll(<String>['cancel', 'execute']));
    expect(visited, isNot(contains('opener')));
    expect(visited, isNot(contains('other')));
    // Three stops inside: close, cancel, execute. Nine Tabs come back round.
    expect(visited.length, 3);

    // Backwards too.
    visited.clear();
    for (int i = 0; i < 6; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      visited.add(_focused());
    }
    expect(visited, isNot(contains('opener')));
    expect(visited, isNot(contains('other')));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
    expect(_focused(), 'opener');
  });

  testWidgets('never wider than the screen less 32 nor taller than the screen less 48; the body scrolls', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _Opener(results: _sink(), tall: true), size: const Size(400, 500));
    await _open(tester);
    expect(tester.takeException(), isNull);
    final Rect dialog = tester.getRect(find.byType(KkDialog));
    expect(dialog.width, 400 - 32);
    expect(dialog.height, 500 - 48);
    expect(find.text('LINE 0'), findsOneWidget);
    final double before = tester.getTopLeft(find.text('LINE 0')).dy;
    await tester.drag(find.text('LINE 3'), const Offset(0, -120));
    await tester.pump();
    expect(tester.getTopLeft(find.text('LINE 0')).dy, lessThan(before));
    // The actions stay in view under the scrolling body.
    expect(tester.getRect(find.text('EXECUTE')).bottom, lessThan(dialog.bottom));
  });

  testWidgets('critical: alert frame, deep head, hazard strip, alert-dialog role', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(
      tester,
      _Opener(results: _sink(), level: KkLevel.critical),
      size: const Size(1000, 700),
    );
    await _open(tester);
    const KkColors c = KkColors.standby;
    final Finder hazard = find.descendant(of: find.byType(KkDialog), matching: find.byType(KkHazard));
    expect(hazard, findsOneWidget);
    expect(tester.getSize(hazard), const Size(518, 8));
    expect(tester.widget<KkHazard>(hazard).running, isTrue);
    expect(tester.widget<Text>(find.text('CONFIRM PROCEDURE')).style!.color, c.ink);
    final KkBox panel = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkDialog), matching: find.byType(KkBox)).first,
    );
    expect(panel.decoration!.edges.top.color, c.alert);
    expect(panel.decoration!.glow, c.glowAlert);
    expect(panel.decoration!.brackets!.color, c.alert);
    expect(panel.decoration!.brackets!.outset, 6);
    expect(tester.getSemantics(find.byType(KkDialog)).getSemanticsData().role, SemanticsRole.alertDialog);
    handle.dispose();
  });

  testWidgets('a plain dialog has the signal frame and the dialog role', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpKk(
      tester,
      _Opener(results: _sink()),
      size: const Size(1000, 700),
      condition: KkCondition.alert,
    );
    await _open(tester);
    const KkColors c = KkColors.alertTheme;
    final KkBox panel = tester.widget<KkBox>(
      find.descendant(of: find.byType(KkDialog), matching: find.byType(KkBox)).first,
    );
    expect(panel.decoration!.edges.top.color, c.signal);
    expect(panel.decoration!.fill, c.bg100);
    expect(panel.decoration!.glow, c.glowSignal);
    expect(find.descendant(of: find.byType(KkDialog), matching: find.byType(KkHazard)), findsNothing);
    final SemanticsData data = tester.getSemantics(find.byType(KkDialog)).getSemanticsData();
    expect(data.role, SemanticsRole.dialog);
    expect(data.label, '手順確認 CONFIRM PROCEDURE');
    expect(tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color, c.scrim);
    handle.dispose();
  });

  testWidgets('wipes in over 0.42s in seven steps, then lifts the clip; wipes out on close', (
    WidgetTester tester,
  ) async {
    await pumpKk(tester, _Opener(results: _sink()), size: const Size(1000, 700), motion: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump();
    ClipRect clip() =>
        tester.widget<ClipRect>(find.descendant(of: find.byType(KkRouteWipe), matching: find.byType(ClipRect)));
    expect(clip().clipBehavior, Clip.hardEdge);
    expect(clip().clipper!.getClip(const Size(700, 100)).width, 0);
    // The scrim does not fade: it is there from the first frame.
    expect(tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color, KkColors.standby.scrim);

    await tester.pump(const Duration(milliseconds: 210));
    final double half = clip().clipper!.getClip(const Size(700, 100)).width;
    expect(half, greaterThan(0));
    expect(half, lessThan(700));
    expect((half / 100).roundToDouble(), half / 100);

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();
    expect(clip().clipBehavior, Clip.none);
    // The body flicker (0.3s delay + 0.5s) has not finished yet, then does.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    final FadeTransition fade = tester.widget<FadeTransition>(
      find.descendant(of: find.byType(KkDialog), matching: find.byType(FadeTransition)),
    );
    expect(fade.opacity.value, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.byType(KkDialog), findsOneWidget);
    expect(clip().clipBehavior, Clip.hardEdge);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    expect(find.byType(KkDialog), findsNothing);
  });

  group('showKkConfirm', () {
    Future<List<bool>> open(WidgetTester tester, {bool danger = false, bool dismissible = true}) async {
      final List<bool> results = <bool>[];
      await pumpKk(
        tester,
        Builder(
          builder: (BuildContext context) => KkButton(
            label: 'ask',
            onPressed: () async {
              results.add(
                await showKkConfirm(
                  context: context,
                  code: 'E-4127',
                  cjk: '緊急停止',
                  en: 'emergency stop',
                  message: '주 펌프 A를 정지합니다.',
                  confirmLabel: 'stop',
                  danger: danger,
                  dismissible: dismissible,
                ),
              );
            },
          ),
        ),
        size: const Size(1000, 700),
      );
      await tester.tap(find.text('ASK'));
      await tester.pump();
      await tester.pump();
      return results;
    }

    testWidgets('true on confirm', (WidgetTester tester) async {
      final List<bool> results = await open(tester);
      expect(find.text('주 펌프 A를 정지합니다.'), findsOneWidget);
      await tester.tap(find.text('STOP'));
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[true]);
    });

    testWidgets('false on cancel, on Escape, on the close button and on the scrim', (WidgetTester tester) async {
      List<bool> results = await open(tester);
      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[false]);

      results = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[false]);

      results = await open(tester);
      await tester.tap(find.byType(KkIconButton));
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[false]);

      results = await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[false]);
    });

    testWidgets('Enter confirms a plain question; a dangerous one starts on cancel', (WidgetTester tester) async {
      List<bool> results = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[true]);

      results = await open(tester, danger: true);
      final KkDialog dialog = tester.widget<KkDialog>(find.byType(KkDialog));
      expect(dialog.level, KkLevel.critical);
      expect(dialog.hazard, isTrue);
      expect(tester.widget<KkButton>(find.byType(KkButton).last).variant, KkButtonVariant.danger);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[false]);
    });

    testWidgets('when it is not dismissible it has no close button', (WidgetTester tester) async {
      final List<bool> results = await open(tester, dismissible: false);
      expect(find.byType(KkIconButton), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(KkDialog), findsOneWidget);
      await tester.tap(find.text('STOP'));
      await tester.pump();
      await tester.pump();
      expect(results, <bool>[true]);
    });
  });

  testWidgets('KkDialog also works inline, without a route', (WidgetTester tester) async {
    int closes = 0;
    await pumpKk(
      tester,
      KkScroll(
        child: KkDialog(
          cjk: '設定',
          width: 720,
          onClose: () => closes++,
          padding: const EdgeInsets.all(4),
          scrollable: false,
          child: const KkText.body('BODY'),
        ),
      ),
      size: const Size(1000, 700),
    );
    expect(tester.takeException(), isNull);
    final Rect dialog = tester.getRect(find.byType(KkDialog));
    expect(dialog.width, 720);
    // No code block: the title starts 16px in.
    expect(tester.getTopLeft(find.text('設定')).dx, dialog.left + 1 + 16);
    expect(tester.getTopLeft(find.text('BODY')).dy, dialog.top + 1 + 40 + 4);
    await tester.tap(find.byType(KkIconButton));
    expect(closes, 1);
    // No actions row: the dialog ends right under the body.
    expect(dialog.bottom, closeTo(tester.getRect(find.text('BODY')).bottom + 4 + 1, 0.5));
  });

  testWidgets('survives an empty dialog and a 0-size screen', (WidgetTester tester) async {
    await pumpKk(tester, const KkDialog(showClose: false, child: KkBox()), size: const Size(40, 40));
    expect(tester.takeException(), isNull);
    await pumpKk(
      tester,
      const KkBox(
        width: 0,
        height: 0,
        child: KkDialog(code: 'X', cjk: '長', en: 'long title that will not fit', child: KkText('x')),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
