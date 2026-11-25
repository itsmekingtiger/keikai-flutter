import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

void _noop() {}

void _noopKeys(Set<Object> _) {}

void _noopEdit(_Unit _, String _) {}

/// One piece of plant equipment, as the tables on this sheet show it.
class _Unit {
  const _Unit({
    required this.id,
    required this.cjk,
    required this.name,
    required this.sector,
    required this.temp,
    required this.pressure,
    required this.load,
    required this.trend,
    this.level,
    this.purge,
    this.setPoint = 120,
  });

  final String id;
  final String cjk;
  final String name;
  final String sector;
  final double temp;
  final double pressure;
  final double load;
  final List<double?> trend;
  final KkLevel? level;

  /// Progress of a running purge, 0 to 1.
  final double? purge;

  /// The pressure the unit is held at, in kPa.
  final double setPoint;
}

const List<_Unit> _units = <_Unit>[
  _Unit(
    id: 'P-0101',
    cjk: '冷却',
    name: 'coolant loop a',
    sector: 'SEC-04',
    temp: 42.7,
    pressure: 256,
    load: 0.42,
    trend: <double?>[40, 41, 41, 42, 43, 42, 43, 42.7],
    level: KkLevel.nominal,
  ),
  _Unit(
    id: 'P-0102',
    cjk: '冷却',
    name: 'coolant loop b',
    sector: 'SEC-04',
    temp: 94.1,
    pressure: 96,
    load: 0.93,
    trend: <double?>[52, 58, 61, 70, 78, 85, 91, 94.1],
    level: KkLevel.critical,
  ),
  _Unit(
    id: 'P-0207',
    cjk: '給水',
    name: 'feed water',
    sector: 'SEC-05',
    temp: 76.4,
    pressure: 204,
    load: 0.71,
    trend: <double?>[70, 72, 71, 74, 75, 77, 76, 76.4],
    level: KkLevel.caution,
    setPoint: 180,
  ),
  _Unit(
    id: 'P-0311',
    cjk: '換気',
    name: 'ventilation',
    sector: 'SEC-07',
    temp: 28.4,
    pressure: 101,
    load: 0.18,
    trend: <double?>[29, 28, 28, 29, 28, 28, 28, 28.4],
    level: KkLevel.nominal,
    purge: 0.6,
    setPoint: 96,
  ),
  _Unit(
    id: 'P-0312',
    cjk: '排気',
    name: 'exhaust',
    sector: 'SEC-07',
    temp: 31.0,
    pressure: 99,
    load: 0.24,
    trend: <double?>[30, 30, 31, 31, 30, 31, 31, 31],
    level: KkLevel.nominal,
  ),
  _Unit(
    id: 'P-0408',
    cjk: '中継',
    name: 'relay pump',
    sector: 'SEC-08',
    temp: 58.9,
    pressure: 188,
    load: 0.55,
    trend: <double?>[55, 57, 56, 58, 59, 58, 59, 58.9],
    level: KkLevel.nominal,
  ),
  _Unit(
    id: 'P-0512',
    cjk: '予備',
    name: 'spare unit',
    sector: 'SEC-12',
    temp: 0,
    pressure: 0,
    load: 0,
    trend: <double?>[12, 11, null, null, null, null, null, null],
    level: KkLevel.offline,
  ),
  _Unit(
    id: 'P-0601',
    cjk: '補助',
    name: 'auxiliary pump',
    sector: 'SEC-04',
    temp: 47.2,
    pressure: 240,
    load: 0.38,
    trend: <double?>[44, 45, 47, 46, 47, 48, 47, 47.2],
    level: KkLevel.nominal,
  ),
];

const List<(String, String, String)> _more = <(String, String, String)>[
  ('冷却', 'coolant loop c', 'SEC-04'),
  ('冷却', 'coolant loop d', 'SEC-04'),
  ('給水', 'feed water b', 'SEC-05'),
  ('給水', 'feed water c', 'SEC-05'),
  ('換気', 'ventilation b', 'SEC-07'),
  ('排気', 'exhaust b', 'SEC-07'),
  ('中継', 'relay pump b', 'SEC-08'),
  ('中継', 'relay pump c', 'SEC-08'),
  ('補助', 'auxiliary pump b', 'SEC-09'),
  ('補助', 'auxiliary pump c', 'SEC-09'),
  ('循環', 'circulation a', 'SEC-10'),
  ('循環', 'circulation b', 'SEC-10'),
];

/// Twenty units for the paged table: the eight above and twelve that run
/// quietly.
final List<_Unit> _fleet = <_Unit>[
  ..._units,
  for (int i = 0; i < _more.length; i++)
    _Unit(
      id: 'P-${(702 + i * 7).toString().padLeft(4, '0')}',
      cjk: _more[i].$1,
      name: _more[i].$2,
      sector: _more[i].$3,
      temp: 36 + (i * 37 % 19) * 1.1,
      pressure: 180 + (i * 53 % 70).toDouble(),
      load: 0.2 + (i * 29 % 40) / 100,
      trend: <double?>[for (int k = 0; k < 8; k++) 36 + ((i * 7 + k * 5) % 9) * 0.8],
      level: KkLevel.nominal,
    ),
];

Object _key(_Unit u) => u.id;

KkLevel? _tempLevel(_Unit u) => switch (u.level) {
  KkLevel.critical => KkLevel.critical,
  KkLevel.caution => KkLevel.caution,
  KkLevel.offline => KkLevel.offline,
  _ => null,
};

String _temp(_Unit u) => u.level == KkLevel.offline ? '---.-' : kkFixed(u.temp, digits: 3, decimals: 1);

KkTableColumn<_Unit> _idColumn({bool summary = false}) => KkTableColumn<_Unit>(
  id: 'id',
  cjk: '符号',
  en: 'id',
  sortable: true,
  value: (_Unit u) => u.id,
  cell: (BuildContext context, _Unit u) => KkTableCode(u.id),
  summary: summary
      ? (BuildContext context, List<_Unit> rows) => const KkTableSummary.title(cjk: '合計', en: 'total')
      : null,
);

KkTableColumn<_Unit> _nameColumn() => KkTableColumn<_Unit>(
  id: 'name',
  cjk: '名称',
  en: 'name',
  width: const KkTableWidth.flex(min: 140),
  sortable: true,
  truncate: true,
  value: (_Unit u) => u.name,
  format: (_Unit u) => u.name.toUpperCase(),
);

KkTableColumn<_Unit> _sectorColumn() =>
    KkTableColumn<_Unit>(id: 'sector', cjk: '区画', en: 'sector', sortable: true, value: (_Unit u) => u.sector);

KkTableColumn<_Unit> _tempColumn({bool summary = false}) => KkTableColumn<_Unit>(
  id: 'temp',
  cjk: '水温',
  en: 'temp',
  unit: '°C',
  numeric: true,
  sortable: true,
  value: (_Unit u) => u.temp,
  cell: (BuildContext context, _Unit u) => KkTableValue(_temp(u), level: _tempLevel(u)),
  summary: summary
      ? (BuildContext context, List<_Unit> rows) {
          final double hottest = rows.fold<double>(0, (double m, _Unit u) => u.temp > m ? u.temp : m);
          return KkTableSummary(kkFixed(hottest, digits: 3, decimals: 1), label: 'max', level: KkLevel.critical);
        }
      : null,
);

KkTableColumn<_Unit> _pressureColumn({bool summary = false}) => KkTableColumn<_Unit>(
  id: 'pressure',
  cjk: '圧力',
  en: 'press',
  unit: 'kPa',
  numeric: true,
  sortable: true,
  value: (_Unit u) => u.pressure,
  format: (_Unit u) => kkFixed(u.pressure, digits: 3),
  summary: summary
      ? (BuildContext context, List<_Unit> rows) {
          final double mean = rows.isEmpty
              ? 0
              : rows.fold<double>(0, (double s, _Unit u) => s + u.pressure) / rows.length;
          return KkTableSummary(kkFixed(mean, digits: 3), label: 'avg');
        }
      : null,
);

KkTableColumn<_Unit> _loadColumn() => KkTableColumn<_Unit>(
  id: 'load',
  cjk: '負荷',
  en: 'load',
  sortable: true,
  value: (_Unit u) => u.load,
  cell: (BuildContext context, _Unit u) =>
      KkTableMeter(u.load, level: u.load >= 0.9 ? KkLevel.critical : (u.load >= 0.7 ? KkLevel.caution : null)),
);

KkTableColumn<_Unit> _flowColumn() => KkTableColumn<_Unit>(
  id: 'flow',
  cjk: '流量',
  en: 'flow',
  cell: (BuildContext context, _Unit u) =>
      KkTableBar(u.pressure / 280, level: u.level == KkLevel.offline ? KkLevel.offline : null),
);

KkTableColumn<_Unit> _trendColumn() => KkTableColumn<_Unit>(
  id: 'trend',
  cjk: '推移',
  en: 'trend · 8h',
  cell: (BuildContext context, _Unit u) => KkTableSpark(u.trend, level: _tempLevel(u), animate: false),
);

KkTableColumn<_Unit> _stateColumn() => KkTableColumn<_Unit>(
  id: 'state',
  cjk: '状態',
  en: 'state',
  sortable: true,
  value: (_Unit u) => u.level?.severity ?? -1,
  cell: (BuildContext context, _Unit u) => KkTableLevel(level: u.level),
);

/// The data table: every part of it, every cell kind and every state.
class TableSheet extends StatelessWidget {
  const TableSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-09',
      cjk: '表',
      en: 'table',
      note: '표. 띠·머리·행·요약·바닥이 한 열 격자를 쓰고, 상태는 색과 낱말과 표식으로 함께 말한다. 값이 바뀌면 칸이 한 번 번쩍인다.',
      sections: <Widget>[
        SheetSection(code: 'T-01', cjk: '表', en: 'data table · every part', child: _Full()),
        SheetSection(code: 'T-02', cjk: '選択', en: 'selection band · bulk actions', child: _Selecting()),
        SheetSection(code: 'T-03', cjk: '状態', en: 'dense · loading · empty · no match', child: _States()),
        SheetSection(code: 'T-04', cjk: '詳細', en: 'detail row · inline edit', child: _DetailAndEdit()),
        SheetSection(code: 'T-05', cjk: '頁', en: 'pagination', child: _Pagers()),
      ],
    );
  }
}

// ── the full table ────────────────────────────────────────────────────────

class _Full extends StatelessWidget {
  const _Full();

  @override
  Widget build(BuildContext context) {
    return SheetItem(
      caption:
          'band · two-line header · code, text, value, meter, bar, sparkline, level · sorted by state · '
          'critical row · row fill · current row · summary · footer',
      width: 1376,
      child: KkDataTable<_Unit>(
        code: 'TBL-01',
        cjk: '機器一覧',
        en: 'equipment',
        meta: '020 UNITS · 14:02:31Z',
        filterable: true,
        actions: const <Widget>[
          KkIconButton(icon: KkIcons.download, size: KkIconButtonSize.sm, semanticLabel: 'Export', onPressed: _noop),
          KkIconButton(icon: KkIcons.refresh, size: KkIconButtonSize.sm, semanticLabel: 'Refresh', onPressed: _noop),
        ],
        rows: _fleet,
        rowKey: _key,
        rowLevel: (_Unit u) => u.level,
        rowFill: (_Unit u) => u.purge,
        showRowNumbers: true,
        selection: KkTableSelection.single,
        selected: const <Object>{'P-0408'},
        sort: const KkTableSort('state', KkSortDirection.descending),
        pageSize: 8,
        pageSizeOptions: const <int>[8, 16, 32],
        onPageSizeChanged: (int _) {},
        boot: false,
        columns: <KkTableColumn<_Unit>>[
          _idColumn(summary: true),
          _nameColumn(),
          _sectorColumn(),
          _tempColumn(summary: true),
          _pressureColumn(summary: true),
          _loadColumn(),
          _flowColumn(),
          _trendColumn(),
          _stateColumn(),
        ],
      ),
    );
  }
}

// ── selection ─────────────────────────────────────────────────────────────

class _Selecting extends StatelessWidget {
  const _Selecting();

  @override
  Widget build(BuildContext context) {
    return SheetItem(
      caption: 'three rows selected · the band counts them · a danger action armed by its first press',
      width: 1376,
      child: KkDataTable<_Unit>(
        code: 'TBL-02',
        cjk: '機器一覧',
        en: 'equipment',
        rows: _units.sublist(0, 5),
        rowKey: _key,
        rowLevel: (_Unit u) => u.level,
        selection: KkTableSelection.multi,
        selected: const <Object>{'P-0101', 'P-0102', 'P-0311'},
        bulkActions: const <KkTableBulkAction>[
          KkTableBulkAction(label: 'acknowledge', cjk: '確認', icon: KkIcons.check, onPressed: _noopKeys),
          KkTableBulkAction(label: 'export', icon: KkIcons.download, onPressed: _noopKeys),
          KkTableBulkAction(
            label: 'trip',
            cjk: '遮断',
            icon: KkIcons.power,
            danger: true,
            confirmLabel: 'confirm trip',
            initiallyArmed: true,
            onPressed: _noopKeys,
          ),
        ],
        boot: false,
        columns: <KkTableColumn<_Unit>>[
          _idColumn(),
          _nameColumn(),
          _sectorColumn(),
          _tempColumn(),
          _pressureColumn(),
          _loadColumn(),
          _stateColumn(),
        ],
      ),
    );
  }
}

// ── dense, loading, empty ─────────────────────────────────────────────────

class _States extends StatelessWidget {
  const _States();

  List<KkTableColumn<_Unit>> _columns() => <KkTableColumn<_Unit>>[
    _idColumn(),
    _nameColumn(),
    _tempColumn(),
    _stateColumn(),
  ];

  @override
  Widget build(BuildContext context) {
    return KkColumn(
      gap: 24,
      shrinkWrap: true,
      children: <Widget>[
        KkRow(
          gap: 32,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: 'dense · 24px rows, 11px type, 36px header',
              width: 672,
              child: KkDataTable<_Unit>(
                code: 'TBL-03',
                en: 'dense',
                dense: true,
                rows: _units,
                rowKey: _key,
                rowLevel: (_Unit u) => u.level,
                showRowNumbers: true,
                boot: false,
                columns: <KkTableColumn<_Unit>>[..._columns(), _loadColumn()],
              ),
            ),
            SheetItem(
              caption: 'loading · the rail scans, skeleton rows stand in',
              width: 672,
              child: KkDataTable<_Unit>(
                code: 'TBL-04',
                en: 'loading',
                meta: 'FETCH 14:02:31Z',
                loading: true,
                skeletonRows: 5,
                rows: const <_Unit>[],
                rowKey: _key,
                initialPageSize: 8,
                boot: false,
                columns: _columns(),
              ),
            ),
          ],
        ),
        KkRow(
          gap: 32,
          cross: KkCrossAlign.start,
          children: <Widget>[
            SheetItem(
              caption: 'no rows',
              width: 672,
              child: KkDataTable<_Unit>(
                code: 'TBL-05',
                en: 'empty',
                rows: const <_Unit>[],
                rowKey: _key,
                boot: false,
                columns: _columns(),
              ),
            ),
            SheetItem(
              caption: 'a filter that matches nothing',
              width: 672,
              child: KkDataTable<_Unit>(
                code: 'TBL-06',
                en: 'filtered',
                filterable: true,
                filter: 'reactor',
                rows: _units,
                rowKey: _key,
                initialPageSize: 8,
                boot: false,
                columns: _columns(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── detail and edit ───────────────────────────────────────────────────────

class _DetailAndEdit extends StatelessWidget {
  const _DetailAndEdit();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return SheetItem(
      caption:
          'the second row is open: void ground, corner mark, dim mono · set points are edited in place '
          '(dashed underline at rest; one editor is open)',
      width: 1376,
      child: KkDataTable<_Unit>(
        code: 'TBL-07',
        cjk: '設定',
        en: 'set points',
        rows: _units.sublist(0, 5),
        rowKey: _key,
        rowLevel: (_Unit u) => u.level == KkLevel.critical ? null : u.level,
        expanded: const <Object>{'P-0102'},
        initiallyEditing: const KkTableCellRef('P-0311', 'setpoint'),
        boot: false,
        detail: (BuildContext context, _Unit u) => KkColumn(
          shrinkWrap: true,
          gap: 4,
          cross: KkCrossAlign.start,
          children: <Widget>[
            KkRow(
              shrinkWrap: true,
              gap: 12,
              children: <Widget>[
                const KkStatusTag.status(KkLevel.critical),
                KkText('E-4127 · COOLANT PRESSURE LOW · 14:02:31Z', color: c.ink),
              ],
            ),
            const KkText('PRESSURE 096 kPa IS UNDER THE SET POINT OF 120 kPa. AUXILIARY PUMP P-0601 IS ON STANDBY.'),
            const KkText('LAST SERVICE 2026-10-02 · NEXT 2027-01-02 · OWNER OP-07'),
          ],
        ),
        columns: <KkTableColumn<_Unit>>[
          _idColumn(),
          _nameColumn(),
          _sectorColumn(),
          _pressureColumn(),
          KkTableColumn<_Unit>(
            id: 'setpoint',
            cjk: '設定圧',
            en: 'set point',
            unit: 'kPa',
            numeric: true,
            width: const KkTableWidth.fixed(160),
            value: (_Unit u) => u.setPoint,
            format: (_Unit u) => kkFixed(u.setPoint, digits: 3),
            editable: true,
            onEdited: _noopEdit,
          ),
          KkTableColumn<_Unit>(
            id: 'note',
            cjk: '所見',
            en: 'remarks',
            width: const KkTableWidth.fixed(280),
            value: (_Unit u) => u.level == KkLevel.offline ? 'LINK DOWN SINCE 13:40Z' : 'NO REMARKS',
            editable: true,
            canEdit: (_Unit u) => u.level != KkLevel.offline,
            onEdited: _noopEdit,
          ),
          _stateColumn(),
        ],
      ),
    );
  }
}

// ── pagination ────────────────────────────────────────────────────────────

class _Pagers extends StatelessWidget {
  const _Pagers();

  @override
  Widget build(BuildContext context) {
    return KkRow(
      gap: 48,
      cross: KkCrossAlign.start,
      children: <Widget>[
        SheetItem(
          caption: 'KkPagination · a page in the middle',
          child: KkPagination(page: 2, pageCount: 12, onChanged: (int _) {}),
        ),
        SheetItem(
          caption: 'first page · back is off',
          child: KkPagination(page: 0, pageCount: 12, onChanged: (int _) {}),
        ),
        SheetItem(
          caption: 'last page · without the end buttons',
          child: KkPagination(page: 11, pageCount: 12, showEnds: false, onChanged: (int _) {}),
        ),
        const SheetItem(caption: 'disabled', child: KkPagination(page: 4, pageCount: 12)),
      ],
    );
  }
}
