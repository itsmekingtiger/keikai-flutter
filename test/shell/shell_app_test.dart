import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

/// A whole screen made of shell widgets only: command bar, rail, breadcrumbs,
/// tabs, a list, a carousel, a side sheet and a toolbar, with a dialog, a
/// sheet and snackbars opened from it.
class _App extends StatefulWidget {
  const _App({required this.results});

  final List<Object?> results;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  int _destination = 0;
  int _tab = 0;
  String _row = 'relay';

  static const List<KkNavItem> _destinations = <KkNavItem>[
    KkNavItem(icon: KkIcons.grid, label: 'board'),
    KkNavItem(icon: KkIcons.bell, label: 'alarms', badge: KkBadge(count: 3)),
    KkNavItem(icon: KkIcons.lock, label: 'secure'),
  ];

  Future<void> _stop() async {
    final bool yes = await showKkConfirm(
      context: context,
      code: 'E-4127',
      cjk: '緊急停止',
      en: 'emergency stop',
      message: '주 펌프 A를 즉시 정지합니다.',
      confirmLabel: 'stop',
      danger: true,
    );
    widget.results.add(yes);
    if (yes && mounted) {
      KkMessenger.of(context).show(code: 'E-4127', level: KkLevel.critical, message: 'pump a stopped');
    }
  }

  Future<void> _detail() async {
    final Object? result = await showKkSheet<String>(
      context: context,
      builder: (BuildContext context) => KkSheet(
        code: 'SEC-04',
        cjk: '冷却',
        en: 'coolant detail',
        actions: <Widget>[
          KkButton(
            label: 'acknowledge',
            variant: KkButtonVariant.primary,
            onPressed: () => Navigator.pop(context, 'ack'),
          ),
        ],
        child: const KkText.body('냉각수 압력이 기준치 아래로 떨어졌습니다.'),
      ),
    );
    widget.results.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return KkScreen(
      commandBar: const KkCommandBar(
        name: 'keikai',
        node: 'hq-03 · node 07',
        followCondition: true,
        cells: <KkCommandCell>[
          KkCommandCell(label: 'sector', value: 'SEC-04'),
          KkCommandCell(label: 'coolant', value: '094.1 °C', level: KkLevel.critical),
        ],
      ),
      nav: KkNavRail(items: _destinations, index: _destination, onChanged: (int i) => setState(() => _destination = i)),
      footer: const KkToolbar(
        hints: <KkToolbarHint>[
          KkToolbarHint(keys: 'F1', label: 'help'),
          KkToolbarHint(keys: 'ESC', label: 'close'),
        ],
        status: 'link ok',
      ),
      body: KkColumn(
        shrinkWrap: true,
        gap: 16,
        children: <Widget>[
          KkBreadcrumbs(
            items: <KkCrumb>[
              KkCrumb(code: 'HQ-03', en: 'board', onPressed: () => setState(() => _destination = 0)),
              const KkCrumb(cjk: '冷却', en: 'coolant'),
            ],
          ),
          KkTabs(
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
            tabs: const <KkTab>[
              KkTab(cjk: '状況', en: 'situation'),
              KkTab(cjk: '映像', en: 'feeds'),
            ],
          ),
          KkTabView(
            index: _tab,
            children: <Widget>[
              KkList(
                children: <Widget>[
                  for (final String name in <String>['power', 'relay', 'coolant'])
                    KkListRow(
                      level: name == 'coolant' ? KkLevel.critical : KkLevel.nominal,
                      cjk: '区',
                      en: name,
                      sub: 'sector $name',
                      current: _row == name,
                      onPressed: () {
                        setState(() => _row = name);
                        if (name == 'coolant') _detail();
                      },
                      trailing: name == 'coolant'
                          ? KkButton(
                              label: 'stop',
                              size: KkButtonSize.sm,
                              variant: KkButtonVariant.danger,
                              onPressed: _stop,
                            )
                          : null,
                    ),
                ],
              ),
              KkCarousel(
                cjk: '監視',
                en: 'feeds',
                items: <KkCarouselItem>[
                  for (int i = 0; i < 8; i++) KkCarouselItem(caption: 'CAM-0$i', child: const KkBox()),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadKkFonts);

  for (final Size size in const <Size>[Size(1280, 800), Size(720, 900), Size(380, 740)]) {
    for (final KkCondition condition in KkCondition.values) {
      testWidgets('a whole shell works at ${size.width.round()}px, ${condition.name}', (WidgetTester tester) async {
        final List<Object?> results = <Object?>[];
        await pumpKk(
          tester,
          _App(results: results),
          size: size,
          condition: condition,
          alignment: null,
        );
        expect(tester.takeException(), isNull);
        final bool compact = size.width < 600;

        // Command bar on top, toolbar on the bottom, both across the width.
        expect(tester.getRect(find.byType(KkCommandBar)), Rect.fromLTWH(0, 0, size.width, 48));
        expect(tester.getRect(find.byType(KkToolbar)), Rect.fromLTWH(0, size.height - 32, size.width, 32));
        // The rail: a column at the left, or a bar above the toolbar.
        final Rect rail = tester.getRect(find.byType(KkNavRail));
        if (compact) {
          expect(rail, Rect.fromLTWH(0, size.height - 32 - 64, size.width, 64));
        } else {
          expect(rail, Rect.fromLTWH(0, 48, 72, size.height - 48 - 32));
        }
        // The command bar hides its caption and all cells but the last when narrow.
        expect(find.text('SECTOR'), compact ? findsNothing : findsOneWidget);
        expect(find.text('COOLANT'), findsWidgets);
        expect(find.text(condition == KkCondition.alert ? 'ALERT' : 'STANDBY'), findsOneWidget);

        // Navigation.
        await tester.tap(find.text('ALARMS'));
        await tester.pump();
        expect(tester.widget<KkNavRail>(find.byType(KkNavRail)).index, 1);
        await tester.tap(find.text('BOARD').last);
        await tester.pump();
        expect(tester.widget<KkNavRail>(find.byType(KkNavRail)).index, 0);

        // The second tab shows the carousel; back to the list.
        await tester.tap(find.text('FEEDS'));
        await tester.pumpAndSettle();
        expect(find.byType(KkCarousel), findsOneWidget);
        expect(find.byType(KkList), findsNothing);
        expect(find.text('01 / 08'), findsOneWidget);
        await tester.tap(find.byWidgetPredicate((Widget w) => w is KkIconButton && w.icon == KkIcons.chevronRight));
        await tester.pump();
        expect(find.text('02 / 08'), findsOneWidget);
        await tester.tap(find.text('SITUATION'));
        await tester.pumpAndSettle();
        expect(find.byType(KkList), findsOneWidget);

        // A row opens the sheet; its action closes it with a value.
        await tester.tap(find.text('sector coolant'));
        await tester.pumpAndSettle();
        final Rect sheet = tester.getRect(find.byType(KkSheet));
        expect(sheet.right, size.width);
        expect(sheet.width, size.width < 400 ? size.width : 400);
        expect(sheet.height, size.height);
        await tester.tap(find.text('ACKNOWLEDGE'));
        await tester.pumpAndSettle();
        expect(find.byType(KkSheet), findsNothing);
        expect(results, <Object?>['ack']);

        // The danger confirm: cancel first, then stop, which reports with a snackbar.
        await tester.tap(find.text('STOP'));
        await tester.pumpAndSettle();
        expect(find.byType(KkDialog), findsOneWidget);
        expect(tester.getRect(find.byType(KkDialog)).width, size.width < 552 ? size.width - 32 : 520);
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        expect(find.byType(KkDialog), findsNothing);
        expect(results, <Object?>['ack', false]);
        expect(find.byType(KkSnackbar), findsNothing);
        await tester.tap(find.text('STOP'));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(KkDialog), matching: find.text('STOP')));
        await tester.pumpAndSettle();
        expect(results, <Object?>['ack', false, true]);
        expect(find.text('pump a stopped'), findsOneWidget);
        final Rect bar = tester.getRect(find.byType(KkSnackbar));
        expect(bar.left, 24);
        expect(bar.bottom, size.height - 32 - 16);
        expect(bar.right, lessThanOrEqualTo(size.width - 24));
        // It leaves by itself.
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        expect(find.byType(KkSnackbar), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the shell runs with motion on and survives a change of condition', (WidgetTester tester) async {
    final List<Object?> results = <Object?>[];
    await pumpKk(tester, _App(results: results), size: const Size(1000, 700), motion: true, alignment: null);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('STOP'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(KkDialog), findsOneWidget);
    // The condition changes while the dialog is open.
    await tester.pumpWidget(
      kkHarness(_App(results: results), condition: KkCondition.alert, motion: true, alignment: null),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(KkDialog), findsOneWidget);
    expect(find.text('ALERT'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(KkDialog), matching: find.text('STOP')));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(KkDialog), findsNothing);
    expect(results, <Object?>[true]);
    expect(find.text('pump a stopped'), findsOneWidget);
    // Let the snackbar's timer run out before the test ends.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(KkSnackbar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
