// The code samples of README.md, kept here so that they are compiled, built
// and laid out by the test run. When a sample changes in one place, change it
// in the other.
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'support/harness.dart';

// ── 시작 ─────────────────────────────────────────────────────────────────

class HqApp extends StatelessWidget {
  const HqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeikaiApp(
      title: 'HQ',
      home: KkBackdrop(
        alignment: Alignment.center,
        child: KkLabel(cjk: '警戒', en: 'keikai for flutter', cjkSize: 44, enSize: 13),
      ),
    );
  }
}

// ── 테마와 조건 ──────────────────────────────────────────────────────────

Widget themedApp(Widget home) {
  return KeikaiApp(
    theme: const KeikaiThemeData(
      motion: KkMotion(timeScale: 1.0), // KkMotion.off 로 모션 전체 끄기
      metrics: KkMetrics(gridGutter: 8), // 치수 토큰 재정의
    ),
    condition: KkCondition.standby, // alert 로 바꾸면 화면이 글리치 후 적색으로 전환
    home: home,
  );
}

Widget alertRegion(Widget child) {
  return KkConditionScope(condition: KkCondition.alert, child: child);
}

// ── 화면 골격과 그리드 ───────────────────────────────────────────────────

class SituationBoard extends StatelessWidget {
  const SituationBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return KkScreen(
      commandBar: const KkCommandBar(
        name: 'KEIKAI',
        node: 'HQ-03 · NODE 07',
        followCondition: true,
        cells: <Widget>[
          KkCommandCell(label: 'sector', value: 'SEC-04'),
          KkCommandCell(label: 'coolant', value: '042.7 °C', level: KkLevel.nominal),
        ],
      ),
      nav: KkNavRail(
        index: 0,
        onChanged: (int index) {},
        items: const <KkNavItem>[
          KkNavItem(icon: KkIcons.grid, label: 'board'),
          KkNavItem(icon: KkIcons.table, label: 'systems'),
          KkNavItem(icon: KkIcons.node, label: 'diagram'),
        ],
      ),
      body: const KkGrid(
        children: <Widget>[
          KkCell(
            span: 8,
            rows: 5,
            child: KkPanel(code: 'SEC-04', cjk: '冷却', en: 'coolant loop', child: KkText('보조 펌프 B 대기 중.')),
          ),
          KkCell(
            span: 4,
            rows: 5,
            child: KkReadout(cjk: '水圧', en: 'pressure', value: '256', unit: 'kPa', level: KkLevel.nominal),
          ),
        ],
      ),
      footer: const KkToolbar(
        hints: <KkToolbarHint>[KkToolbarHint(keys: 'F1', label: 'help')],
        status: 'LINK OK',
      ),
    );
  }
}

Widget responsiveColumns(BuildContext context) {
  final int columns = const KkResponsive<int>(compact: 1, medium: 2, expanded: 3).of(context);
  return KkText('$columns columns');
}

// ── 조작과 입력 ──────────────────────────────────────────────────────────

class SetPointForm extends StatefulWidget {
  const SetPointForm({super.key});

  @override
  State<SetPointForm> createState() => _SetPointFormState();
}

class _SetPointFormState extends State<SetPointForm> {
  String sector = 'coolant';
  double setPoint = 0.6;
  bool auto = true;

  @override
  Widget build(BuildContext context) {
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkTextField(cjk: '識別符号', en: 'call sign', placeholder: 'SEC-04', maxLength: 6, onChanged: (String v) {}),
        KkSelect<String>(
          cjk: '区画',
          en: 'sector',
          value: sector,
          onChanged: (String? v) => setState(() => sector = v ?? sector),
          options: const <KkSelectOption<String>>[
            KkSelectOption<String>(value: 'power', label: 'Power', cjk: '電源', code: 'SEC-01'),
            KkSelectOption<String>(value: 'coolant', label: 'Coolant', cjk: '冷却', code: 'SEC-04'),
          ],
        ),
        KkSlider(cjk: '設定圧', en: 'set point', value: setPoint, onChanged: (double v) => setState(() => setPoint = v)),
        KkSwitch(value: auto, onChanged: (bool v) => setState(() => auto = v)),
        KkRow(
          gap: 8,
          shrinkWrap: true,
          children: <Widget>[
            KkButton(label: 'cancel', variant: KkButtonVariant.ghost, onPressed: () {}),
            KkButton(
              label: 'execute',
              cjk: '実行',
              variant: KkButtonVariant.primary,
              onPressed: () => confirmStop(context),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 겹침면 ───────────────────────────────────────────────────────────────

Future<void> confirmStop(BuildContext context) async {
  final bool stop = await showKkConfirm(
    context: context,
    code: 'E-4127',
    cjk: '緊急停止',
    en: 'emergency stop',
    message: '주 펌프 A를 즉시 정지합니다.',
    confirmLabel: 'stop',
    confirmCjk: '停止',
    danger: true,
  );
  if (stop && context.mounted) {
    KkMessenger.of(context).show(code: 'SEC-04', message: 'pump A stopped', level: KkLevel.caution);
  }
}

// ── 계측 ─────────────────────────────────────────────────────────────────

Widget instruments() {
  return const KkColumn(
    gap: 8,
    shrinkWrap: true,
    cross: KkCrossAlign.start,
    children: <Widget>[
      KkAlertBar(
        level: KkLevel.critical,
        cjk: '警報',
        title: 'coolant pressure low',
        sub: '冷却水圧 低下 · SEC-04',
        code: 'E-4127',
      ),
      KkMeter(cjk: '負荷', en: 'load', value: 0.78, unit: '%', valueText: '078'),
      KkTimer.countdown(from: Duration(minutes: 5), cjk: '猶予', en: 'hold', autostart: false),
    ],
  );
}

// ── 차트 ─────────────────────────────────────────────────────────────────

Widget temperatureChart() {
  return const KkTimeSeries(
    cjk: '水温',
    en: 'coolant temp',
    series: <KkSeries>[
      KkSeries(name: 'loop a', values: <double>[41.2, 41.9, 42.4, 43.8, 47.1, 52.6, 58.0], area: true),
      KkSeries(name: 'loop b', values: <double>[40.8, 40.9, 41.3, 41.2, 41.8, 42.0, 42.3]),
    ],
    thresholds: <KkThreshold>[KkThreshold(55, label: 'limit', level: KkLevel.critical)],
  );
}

// ── 다이어그램 ───────────────────────────────────────────────────────────

const String signalPath = '''
flow LR
SEN>PT-104] ==> ADC[ADC-02|SAMPLER]
ADC ==> FLT[DSP-01|FILTER|濾波]
FLT ==> CMP{LIMIT}
CMP -->|IN RANGE| LOG[LOG-01|ARCHIVE]
CMP ==>|OVER|:::critical ALM((ANN-07|ALARM|警報)):::critical
ALM -.-> PGR[PGR-03|PAGER]:::offline
''';

Widget signalDiagram() {
  return KkNodeGraph(diagram: KkDiagram.parse(signalPath), cjk: '信号経路', en: 'signal path', height: 280);
}

// ── 표 ───────────────────────────────────────────────────────────────────

class Pump {
  const Pump(this.id, this.name, this.temp, this.load, this.level);

  final String id;
  final String name;
  final double temp;
  final double load;
  final KkLevel level;
}

const List<Pump> pumps = <Pump>[
  Pump('P-0101', 'COOLANT LOOP A', 42.7, 0.42, KkLevel.nominal),
  Pump('P-0102', 'COOLANT LOOP B', 94.1, 0.93, KkLevel.critical),
  Pump('P-0207', 'FEED WATER', 76.4, 0.71, KkLevel.caution),
];

Widget pumpTable() {
  return KkDataTable<Pump>(
    code: 'TBL-01',
    cjk: '機器一覧',
    en: 'equipment',
    rows: pumps,
    rowKey: (Pump p) => p.id,
    rowLevel: (Pump p) => p.level == KkLevel.critical ? KkLevel.critical : null,
    selection: KkTableSelection.multi,
    filterable: true,
    pageSize: 8,
    bulkActions: <KkTableBulkAction>[
      KkTableBulkAction(label: 'acknowledge', cjk: '確認', onPressed: (Set<Object> keys) {}),
      KkTableBulkAction(label: 'trip', cjk: '遮断', danger: true, onPressed: (Set<Object> keys) {}),
    ],
    columns: <KkTableColumn<Pump>>[
      KkTableColumn<Pump>(
        id: 'id',
        cjk: '符号',
        en: 'id',
        value: (Pump p) => p.id,
        cell: (BuildContext context, Pump p) => KkTableCode(p.id),
      ),
      KkTableColumn<Pump>(
        id: 'name',
        cjk: '名称',
        en: 'name',
        value: (Pump p) => p.name,
        width: const KkTableWidth.flex(),
        sortable: true,
      ),
      KkTableColumn<Pump>(
        id: 'temp',
        cjk: '水温',
        en: 'temp',
        unit: '°C',
        numeric: true,
        sortable: true,
        value: (Pump p) => p.temp,
        format: (Pump p) => p.temp.toStringAsFixed(1),
      ),
      KkTableColumn<Pump>(
        id: 'load',
        cjk: '負荷',
        en: 'load',
        value: (Pump p) => p.load,
        cell: (BuildContext context, Pump p) => KkTableMeter(p.load),
      ),
      KkTableColumn<Pump>(
        id: 'state',
        cjk: '状態',
        en: 'state',
        value: (Pump p) => p.level.index,
        cell: (BuildContext context, Pump p) => KkTableLevel(level: p.level),
      ),
    ],
  );
}

// ── 모션 ─────────────────────────────────────────────────────────────────

Widget motionSamples(String reading) {
  return KkColumn(
    gap: 8,
    shrinkWrap: true,
    cross: KkCrossAlign.start,
    children: <Widget>[
      const KkBoot(child: KkText.en('wiped in over 0.42s in 7 steps')),
      KkScramble(reading), // 값이 바뀌면 숫자가 섞였다가 자리 잡는다
      const KkBlink(child: KkText.en('standing by')),
      const KkHazard(running: true, height: 8, width: 200),
    ],
  );
}

void main() {
  setUpAll(loadKkFonts);

  testWidgets('the first sample is a whole app', (WidgetTester tester) async {
    await tester.pumpWidget(const HqApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('警戒'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme, motion and condition', (WidgetTester tester) async {
    await tester.pumpWidget(
      themedApp(KkColumn(children: <Widget>[const KkText('page'), alertRegion(const KkText('region'))])),
    );
    await tester.pump(const Duration(seconds: 1));
    // Only the region is red; the page around it keeps the app's condition.
    final BuildContext region = tester.element(find.text('region'));
    expect(KeikaiTheme.of(region).colors.signal, KkColors.alertTheme.signal);
    final BuildContext page = tester.element(find.text('page'));
    expect(KeikaiTheme.of(page).colors.signal, KkColors.standby.signal);
    expect(KeikaiApp.conditionOf(page), KkCondition.standby);
  });

  testWidgets('the screen skeleton lays out at every window class', (WidgetTester tester) async {
    for (final Size size in const <Size>[Size(390, 800), Size(720, 900), Size(1280, 800), Size(1920, 1080)]) {
      await pumpKk(tester, const SituationBoard(), size: size, alignment: null);
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.byType(KkPanel), findsOneWidget);
      expect(find.byType(KkReadout), findsOneWidget);
    }
  });

  testWidgets('responsive values follow the window class', (WidgetTester tester) async {
    await pumpKk(tester, const Builder(builder: responsiveColumns), size: const Size(390, 800));
    expect(find.text('1 columns'), findsOneWidget);
    await pumpKk(tester, const Builder(builder: responsiveColumns), size: const Size(1280, 800));
    expect(find.text('3 columns'), findsOneWidget);
  });

  testWidgets('the form builds, confirms and reports', (WidgetTester tester) async {
    await pumpKk(tester, const SetPointForm(), padding: const EdgeInsets.all(16));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('EXECUTE'));
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsOneWidget);
    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    expect(find.byType(KkDialog), findsNothing);
    expect(find.byType(KkSnackbar), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(KkSnackbar), findsNothing);
  });

  testWidgets('instruments, chart, diagram, table and motion samples build', (WidgetTester tester) async {
    for (final Widget sample in <Widget>[
      instruments(),
      KkBox(width: 520, child: temperatureChart()),
      KkBox(width: 720, child: signalDiagram()),
      KkBox(width: 960, height: 420, child: pumpTable()),
      motionSamples('094.1'),
    ]) {
      await pumpKk(tester, sample, size: const Size(1280, 800), padding: const EdgeInsets.all(16));
      expect(tester.takeException(), isNull, reason: '${sample.runtimeType}');
    }
    // The table shows its three rows, with the critical one first in data order.
    await pumpKk(tester, KkBox(width: 960, height: 420, child: pumpTable()), size: const Size(1280, 800));
    expect(find.text('P-0102'), findsOneWidget);
    expect(find.byType(KkTableMeter), findsNWidgets(3));
  });
}
