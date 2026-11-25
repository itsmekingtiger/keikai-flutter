import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

/// The catalogue sheet of the controls family: every control in its variants
/// and states. The specimens are live; the ones marked HOVER, FOCUS or
/// PRESSED are pinned in that state.
class ControlsSheet extends StatelessWidget {
  const ControlsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-03',
      cjk: '操作',
      en: 'controls',
      note: '조작 요소의 테두리는 signal. 선택 표시는 자리를 미리 잡아 두고 채움과 보임만 바꾼다.',
      sections: <Widget>[
        _TagSection(),
        _ButtonSection(),
        _IconButtonSection(),
        _BadgeFabSection(),
        _SegmentedChipSection(),
        _SelectionSection(),
        _SliderSection(),
        _ProgressSection(),
        _DividerSection(),
        _EmptySection(),
      ],
    );
  }
}

void _noop() {}

/// Holds one value so a specimen can be operated.
class _Value<T> extends StatefulWidget {
  const _Value({super.key, required this.initial, required this.builder});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> set) builder;

  @override
  State<_Value<T>> createState() => _ValueState<T>();
}

class _ValueState<T> extends State<_Value<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, (T next) => setState(() => _value = next));
  }
}

/// Specimens side by side, wrapping, with their captions on one line.
class _Flow extends StatelessWidget {
  const _Flow({required this.children, this.gap = 24});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return KkWrap(gap: gap, runGap: 20, cross: KkCrossAlign.end, children: children);
  }
}

class _MatrixRow {
  const _MatrixRow(this.label, this.cells);

  final String label;
  final List<Widget> cells;
}

/// A table of specimens: one row per variant, one column per state.
class _Matrix extends StatelessWidget {
  const _Matrix({required this.columns, required this.rows, this.cellWidth = 200});

  static const double labelWidth = 112;

  final List<String> columns;
  final List<_MatrixRow> rows;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 14,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkRow(
          shrinkWrap: true,
          children: <Widget>[
            const KkBox(width: labelWidth),
            for (final String column in columns)
              KkBox(
                width: cellWidth,
                child: KkText.num(column, size: 10, color: c.inkFaint),
              ),
          ],
        ),
        for (final _MatrixRow row in rows)
          KkRow(
            shrinkWrap: true,
            children: <Widget>[
              KkBox(
                width: labelWidth,
                child: KkText.num(row.label, size: 10, color: c.inkDim),
              ),
              for (final Widget cell in row.cells)
                KkBox(width: cellWidth, alignment: Alignment.centerLeft, child: cell),
            ],
          ),
      ],
    );
  }
}

Widget _hover(Widget child) => KkStateOverride(hovered: true, child: child);
Widget _focus(Widget child) => KkStateOverride(focused: true, child: child);
Widget _press(Widget child) => KkStateOverride(pressed: true, child: child);

// ── C-01 ────────────────────────────────────────────────────────────────

class _TagSection extends StatelessWidget {
  const _TagSection();

  @override
  Widget build(BuildContext context) {
    const List<KkLevel?> levels = <KkLevel?>[KkLevel.nominal, KkLevel.caution, KkLevel.critical, KkLevel.offline, null];
    return SheetSection(
      code: 'C-01',
      cjk: '標識',
      en: 'status tag · kbd',
      child: KkColumn(
        gap: 20,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Flow(
            gap: 12,
            children: <Widget>[
              for (final KkLevel? level in levels)
                SheetItem(caption: 'OUTLINE · ${level?.name ?? 'info'}', child: KkStatusTag.status(level)),
              for (final KkLevel? level in levels)
                SheetItem(
                  caption: 'SOLID · ${level?.name ?? 'info'}',
                  child: KkStatusTag.status(level, variant: KkStatusTagVariant.solid),
                ),
            ],
          ),
          const _Flow(
            gap: 12,
            children: <Widget>[
              SheetItem(
                caption: 'LG · OUTLINE',
                child: KkStatusTag.status(KkLevel.nominal, size: KkStatusTagSize.lg),
              ),
              SheetItem(
                caption: 'LG · SOLID',
                child: KkStatusTag.status(
                  KkLevel.critical,
                  size: KkStatusTagSize.lg,
                  variant: KkStatusTagVariant.solid,
                ),
              ),
              SheetItem(
                caption: 'NO LEVEL',
                child: KkStatusTag('standby', cjk: '待機'),
              ),
              SheetItem(
                caption: 'NO LEVEL · SOLID',
                child: KkStatusTag('sec-04', variant: KkStatusTagVariant.solid),
              ),
              SheetItem(
                caption: 'ICON',
                child: KkStatusTag('live', icon: KkIcons.pulse),
              ),
              SheetItem(
                caption: 'NO GLYPH',
                child: KkStatusTag('caution', level: KkLevel.caution, glyph: false),
              ),
              SheetItem(caption: 'WORD ONLY', child: KkStatusTag.status(KkLevel.offline, showCjk: false)),
              SheetItem(caption: 'KBD', child: KkKbd('F5')),
              SheetItem(caption: 'KBD', child: KkKbd('ESC')),
              SheetItem(caption: 'KBD', child: KkKbd('CTRL+K')),
              SheetItem(caption: 'KBD', child: KkKbd('ENTER')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-02 ────────────────────────────────────────────────────────────────

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  static const List<(KkButtonVariant, String, String, String)> _variants = <(KkButtonVariant, String, String, String)>[
    (KkButtonVariant.outline, 'OUTLINE', 'acknowledge', '確認'),
    (KkButtonVariant.primary, 'PRIMARY', 'engage', '起動'),
    (KkButtonVariant.danger, 'DANGER', 'abort', '中止'),
    (KkButtonVariant.ghost, 'GHOST', 'detail', '詳細'),
    (KkButtonVariant.tonal, 'TONAL', 'standby', '待機'),
  ];

  @override
  Widget build(BuildContext context) {
    KkButton button(KkButtonVariant variant, String label, String cjk, {bool live = true, bool loading = false}) {
      return KkButton(label: label, cjk: cjk, variant: variant, loading: loading, onPressed: live ? _noop : null);
    }

    return SheetSection(
      code: 'C-02',
      cjk: '押釦',
      en: 'button',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Matrix(
            columns: const <String>['DEFAULT', 'HOVER', 'FOCUS', 'PRESSED', 'DISABLED', 'LOADING'],
            rows: <_MatrixRow>[
              for (final (KkButtonVariant variant, String name, String label, String cjk) in _variants)
                _MatrixRow(name, <Widget>[
                  button(variant, label, cjk),
                  _hover(button(variant, label, cjk)),
                  _focus(button(variant, label, cjk)),
                  _press(button(variant, label, cjk)),
                  button(variant, label, cjk, live: false),
                  button(variant, label, cjk, loading: true),
                ]),
            ],
          ),
          const _Flow(
            children: <Widget>[
              SheetItem(
                caption: 'SM · 28',
                child: KkButton(label: 'filter', icon: KkIcons.filter, size: KkButtonSize.sm, onPressed: _noop),
              ),
              SheetItem(
                caption: 'MD · 36',
                child: KkButton(label: 'refresh', icon: KkIcons.refresh, onPressed: _noop),
              ),
              SheetItem(
                caption: 'LG · 48',
                child: KkButton(
                  label: 'engage',
                  cjk: '起動',
                  size: KkButtonSize.lg,
                  variant: KkButtonVariant.primary,
                  onPressed: _noop,
                ),
              ),
              SheetItem(
                caption: 'TRAILING ICON',
                child: KkButton(label: 'next sector', trailingIcon: KkIcons.chevronRight, onPressed: _noop),
              ),
              SheetItem(
                caption: 'CJK ONLY',
                child: KkButton(cjk: '確認', variant: KkButtonVariant.tonal, onPressed: _noop),
              ),
              SheetItem(
                caption: 'ICON ONLY',
                child: KkButton(icon: KkIcons.download, onPressed: _noop, semanticLabel: 'Download'),
              ),
              SheetItem(
                caption: 'DANGER · SM',
                child: KkButton(
                  label: 'purge',
                  icon: KkIcons.trash,
                  size: KkButtonSize.sm,
                  variant: KkButtonVariant.danger,
                  onPressed: _noop,
                ),
              ),
              SheetItem(
                caption: 'EXPAND · 320',
                width: 320,
                child: KkButton(
                  label: 'acknowledge all',
                  cjk: '一括確認',
                  variant: KkButtonVariant.primary,
                  expand: true,
                  onPressed: _noop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-03 ────────────────────────────────────────────────────────────────

class _IconButtonSection extends StatelessWidget {
  const _IconButtonSection();

  @override
  Widget build(BuildContext context) {
    KkIconButton button(KkIconButtonVariant variant, {bool live = true, bool? toggled}) {
      return KkIconButton(
        icon: KkIcons.settings,
        variant: variant,
        toggled: toggled,
        onPressed: live ? _noop : null,
        semanticLabel: 'Settings',
      );
    }

    return SheetSection(
      code: 'C-03',
      cjk: '記号釦',
      en: 'icon button',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Matrix(
            cellWidth: 104,
            columns: const <String>['DEFAULT', 'HOVER', 'FOCUS', 'TOGGLED', 'DISABLED', 'DISABLED · ON'],
            rows: <_MatrixRow>[
              for (final KkIconButtonVariant variant in KkIconButtonVariant.values)
                _MatrixRow(variant.name.toUpperCase(), <Widget>[
                  button(variant),
                  _hover(button(variant)),
                  _focus(button(variant)),
                  button(variant, toggled: true),
                  button(variant, live: false),
                  button(variant, live: false, toggled: true),
                ]),
            ],
          ),
          _Flow(
            children: <Widget>[
              const SheetItem(
                caption: 'SM · 24',
                child: KkIconButton(
                  icon: KkIcons.close,
                  size: KkIconButtonSize.sm,
                  onPressed: _noop,
                  semanticLabel: 'Close',
                ),
              ),
              const SheetItem(
                caption: 'MD · 32',
                child: KkIconButton(
                  icon: KkIcons.search,
                  variant: KkIconButtonVariant.outline,
                  onPressed: _noop,
                  semanticLabel: 'Search',
                ),
              ),
              const SheetItem(
                caption: 'LG · 40',
                child: KkIconButton(
                  icon: KkIcons.power,
                  size: KkIconButtonSize.lg,
                  variant: KkIconButtonVariant.filled,
                  onPressed: _noop,
                  semanticLabel: 'Power',
                ),
              ),
              const SheetItem(
                caption: 'BADGE · COUNT',
                child: KkIconButton(
                  icon: KkIcons.bell,
                  variant: KkIconButtonVariant.outline,
                  badge: KkBadge(count: 7),
                  onPressed: _noop,
                  semanticLabel: 'Alarms, 7 waiting',
                ),
              ),
              const SheetItem(
                caption: 'BADGE · DOT',
                child: KkIconButton(
                  icon: KkIcons.file,
                  badge: KkBadge.dot(level: KkLevel.caution),
                  onPressed: _noop,
                  semanticLabel: 'Log, new entries',
                ),
              ),
              SheetItem(
                caption: 'TOGGLE',
                child: _Value<bool>(
                  initial: true,
                  builder: (BuildContext context, bool on, ValueChanged<bool> set) => KkIconButton(
                    icon: on ? KkIcons.bell : KkIcons.bellOff,
                    variant: KkIconButtonVariant.outline,
                    toggled: on,
                    onPressed: () => set(!on),
                    semanticLabel: 'Audible alarm',
                  ),
                ),
              ),
              SheetItem(
                caption: 'SPIN ON PRESS',
                child: _Value<int>(
                  initial: 0,
                  builder: (BuildContext context, int turns, ValueChanged<int> set) => KkIconButton(
                    icon: KkIcons.refresh,
                    variant: KkIconButtonVariant.outline,
                    spinTrigger: turns,
                    onPressed: () => set(turns + 1),
                    semanticLabel: 'Refresh',
                  ),
                ),
              ),
              const SheetItem(
                caption: 'SPINNING',
                child: KkIconButton(
                  icon: KkIcons.sync,
                  variant: KkIconButtonVariant.tonal,
                  spinning: true,
                  onPressed: _noop,
                  semanticLabel: 'Synchronising',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-04 ────────────────────────────────────────────────────────────────

class _BadgeFabSection extends StatelessWidget {
  const _BadgeFabSection();

  @override
  Widget build(BuildContext context) {
    return SheetSection(
      code: 'C-04',
      cjk: '計数',
      en: 'badge · fab',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          const _Flow(
            children: <Widget>[
              SheetItem(caption: 'COUNT', child: KkBadge(count: 3)),
              SheetItem(caption: 'COUNT', child: KkBadge(count: 12)),
              SheetItem(caption: 'OVER MAX', child: KkBadge(count: 128)),
              SheetItem(
                caption: 'LABEL',
                child: KkBadge(label: 'NEW'),
              ),
              SheetItem(
                caption: 'CAUTION',
                child: KkBadge(count: 4, level: KkLevel.caution),
              ),
              SheetItem(
                caption: 'NOMINAL',
                child: KkBadge(count: 0, level: KkLevel.nominal),
              ),
              SheetItem(
                caption: 'OFFLINE',
                child: KkBadge(count: 2, level: KkLevel.offline),
              ),
              SheetItem(caption: 'DOT', child: KkBadge.dot()),
              SheetItem(
                caption: 'DOT · CAUTION',
                child: KkBadge.dot(level: KkLevel.caution),
              ),
              SheetItem(
                caption: 'ANCHOR',
                child: KkBadgeAnchor(badge: KkBadge(count: 5), child: KkStatusTag('ch.12')),
              ),
              SheetItem(
                caption: 'ANCHOR · DOT',
                child: KkBadgeAnchor(badge: KkBadge.dot(), child: KkIcon(KkIcons.bell, size: 16)),
              ),
            ],
          ),
          _Flow(
            gap: 32,
            children: <Widget>[
              const SheetItem(
                caption: 'FAB · 56×64',
                child: KkFab(icon: KkIcons.plus, onPressed: _noop, semanticLabel: 'New report'),
              ),
              SheetItem(
                caption: 'HOVER',
                child: _hover(const KkFab(icon: KkIcons.plus, onPressed: _noop, semanticLabel: 'New report')),
              ),
              SheetItem(
                caption: 'FOCUS',
                child: _focus(const KkFab(icon: KkIcons.plus, onPressed: _noop, semanticLabel: 'New report')),
              ),
              const SheetItem(
                caption: 'SM · 40×46',
                child: KkFab(icon: KkIcons.edit, size: KkFabSize.sm, onPressed: _noop, semanticLabel: 'Edit'),
              ),
              const SheetItem(
                caption: 'DANGER',
                child: KkFab(
                  icon: KkIcons.power,
                  variant: KkFabVariant.danger,
                  onPressed: _noop,
                  semanticLabel: 'Emergency stop',
                ),
              ),
              const SheetItem(
                caption: 'DISABLED',
                child: KkFab(icon: KkIcons.plus, semanticLabel: 'New report'),
              ),
              const SheetItem(
                caption: 'EXTENDED · 48',
                child: KkFab.extended(label: 'new report', icon: KkIcons.plus, onPressed: _noop),
              ),
              SheetItem(
                caption: 'EXTENDED · HOVER',
                child: _hover(const KkFab.extended(label: 'new report', icon: KkIcons.plus, onPressed: _noop)),
              ),
              const SheetItem(
                caption: 'EXTENDED · DANGER',
                child: KkFab.extended(
                  label: 'scram',
                  icon: KkIcons.power,
                  variant: KkFabVariant.danger,
                  onPressed: _noop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-05 ────────────────────────────────────────────────────────────────

class _SegmentedChipSection extends StatelessWidget {
  const _SegmentedChipSection();

  static const List<KkSegment<String>> _ranges = <KkSegment<String>>[
    KkSegment<String>(value: '1h', label: '1h'),
    KkSegment<String>(value: '6h', label: '6h'),
    KkSegment<String>(value: '24h', label: '24h'),
    KkSegment<String>(value: '7d', label: '7d'),
  ];

  static const List<KkSegment<String>> _levels = <KkSegment<String>>[
    KkSegment<String>(value: 'all', label: 'all', cjk: '全体'),
    KkSegment<String>(value: 'critical', label: 'critical', cjk: '警報'),
    KkSegment<String>(value: 'caution', label: 'caution', cjk: '注意'),
    KkSegment<String>(value: 'offline', label: 'offline', cjk: '断線', enabled: false),
  ];

  static const List<KkSegment<int>> _channels = <KkSegment<int>>[
    KkSegment<int>(value: 1, label: 'ch.1'),
    KkSegment<int>(value: 2, label: 'ch.2'),
    KkSegment<int>(value: 3, label: 'ch.3'),
    KkSegment<int>(value: 4, label: 'ch.4'),
    KkSegment<int>(value: 5, label: 'ch.5'),
  ];

  @override
  Widget build(BuildContext context) {
    return SheetSection(
      code: 'C-05',
      cjk: '切替',
      en: 'segmented · chip',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Flow(
            children: <Widget>[
              SheetItem(
                caption: 'SINGLE',
                child: _Value<String>(
                  initial: '6h',
                  builder: (BuildContext context, String value, ValueChanged<String> set) =>
                      KkSegmented<String>(segments: _ranges, value: value, onChanged: set),
                ),
              ),
              SheetItem(
                caption: 'SINGLE · CJK · ONE DISABLED',
                child: _Value<String>(
                  initial: 'critical',
                  builder: (BuildContext context, String value, ValueChanged<String> set) =>
                      KkSegmented<String>(segments: _levels, value: value, onChanged: set),
                ),
              ),
              SheetItem(
                caption: 'MULTI · ADJACENT ON',
                child: _Value<Set<int>>(
                  initial: const <int>{1, 2, 4},
                  builder: (BuildContext context, Set<int> values, ValueChanged<Set<int>> set) =>
                      KkSegmented<int>.multi(segments: _channels, values: values, onValuesChanged: set),
                ),
              ),
            ],
          ),
          _Flow(
            children: <Widget>[
              SheetItem(
                caption: 'HOVER',
                child: _hover(const KkSegmented<String>(segments: _ranges, value: '24h', onChanged: _noopString)),
              ),
              SheetItem(
                caption: 'FOCUS',
                child: _focus(const KkSegmented<String>(segments: _ranges, value: '6h', onChanged: _noopString)),
              ),
              const SheetItem(
                caption: 'NO LAMP',
                child: KkSegmented<String>(segments: _ranges, value: '1h', lamp: false, onChanged: _noopString),
              ),
              const SheetItem(
                caption: 'DISABLED',
                child: KkSegmented<String>(segments: _ranges, value: '6h'),
              ),
              const SheetItem(
                caption: 'EXPAND · 400',
                width: 400,
                child: KkSegmented<String>(segments: _ranges, value: '7d', expand: true, onChanged: _noopString),
              ),
            ],
          ),
          _Flow(
            gap: 16,
            children: <Widget>[
              const SheetItem(
                caption: 'ASSIST',
                child: KkChip(label: 'add note', icon: KkIcons.plus, onPressed: _noop),
              ),
              SheetItem(
                caption: 'ASSIST · HOVER',
                child: _hover(const KkChip(label: 'add note', icon: KkIcons.plus, onPressed: _noop)),
              ),
              SheetItem(
                caption: 'FILTER · ON',
                child: _Value<bool>(
                  initial: true,
                  builder: (BuildContext context, bool on, ValueChanged<bool> set) =>
                      KkChip.filter(label: 'critical', cjk: '警報', selected: on, onSelected: set),
                ),
              ),
              SheetItem(
                caption: 'FILTER · OFF',
                child: _Value<bool>(
                  initial: false,
                  builder: (BuildContext context, bool on, ValueChanged<bool> set) =>
                      KkChip.filter(label: 'caution', cjk: '注意', selected: on, onSelected: set),
                ),
              ),
              SheetItem(
                caption: 'FILTER · FOCUS',
                child: _focus(const KkChip.filter(label: 'sec-04', selected: true, onSelected: _noopBool)),
              ),
              const SheetItem(
                caption: 'SUGGESTION',
                child: KkChip.suggestion(label: 'last 24h', onPressed: _noop),
              ),
              const SheetItem(
                caption: 'INPUT',
                child: KkChip.input(label: 'op-07', onRemove: _noop),
              ),
              const SheetItem(
                caption: 'INPUT · CJK',
                child: KkChip.input(label: 'coolant', cjk: '冷却', onRemove: _noop),
              ),
              const SheetItem(
                caption: 'DISABLED',
                child: KkChip(label: 'add note', icon: KkIcons.plus),
              ),
              const SheetItem(
                caption: 'DISABLED · ON',
                child: KkChip.filter(label: 'critical', selected: true),
              ),
              const SheetItem(
                caption: 'DISABLED · INPUT',
                child: KkChip.input(label: 'op-07'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _noopString(String value) {}
void _noopBool(bool value) {}
void _noopTristate(bool? value) {}
void _noopDouble(double value) {}

// ── C-06 ────────────────────────────────────────────────────────────────

class _SelectionSection extends StatelessWidget {
  const _SelectionSection();

  static const List<KkRadioOption<String>> _modes = <KkRadioOption<String>>[
    KkRadioOption<String>(value: 'auto', label: 'auto', cjk: '自動'),
    KkRadioOption<String>(value: 'manual', label: 'manual', cjk: '手動'),
    KkRadioOption<String>(value: 'remote', label: 'remote', cjk: '遠隔'),
    KkRadioOption<String>(value: 'locked', label: 'locked', cjk: '施錠', enabled: false),
  ];

  @override
  Widget build(BuildContext context) {
    return SheetSection(
      code: 'C-06',
      cjk: '選択',
      en: 'checkbox · radio · switch',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Flow(
            children: <Widget>[
              SheetItem(
                caption: 'CHECKBOX · TRISTATE',
                child: _Value<bool?>(
                  initial: false,
                  builder: (BuildContext context, bool? value, ValueChanged<bool?> set) =>
                      KkCheckbox(value: value, tristate: true, label: 'log to file', cjk: '記録', onChanged: set),
                ),
              ),
              const SheetItem(
                caption: 'CHECKED',
                child: KkCheckbox(value: true, label: 'notify op-07', cjk: '通知', onChanged: _noopTristate),
              ),
              const SheetItem(
                caption: 'MIXED',
                child: KkCheckbox(value: null, tristate: true, label: 'all sectors', onChanged: _noopTristate),
              ),
              SheetItem(
                caption: 'HOVER',
                child: _hover(const KkCheckbox(value: false, label: 'auto ack', onChanged: _noopTristate)),
              ),
              SheetItem(
                caption: 'FOCUS',
                child: _focus(const KkCheckbox(value: true, label: 'auto ack', onChanged: _noopTristate)),
              ),
              const SheetItem(
                caption: 'ERROR',
                child: KkCheckbox(value: false, error: true, label: 'confirm purge', onChanged: _noopTristate),
              ),
              const SheetItem(
                caption: 'DISABLED',
                child: KkCheckbox(value: false, label: 'interlock'),
              ),
              const SheetItem(
                caption: 'DISABLED · CHECKED',
                child: KkCheckbox(value: true, label: 'interlock'),
              ),
              const SheetItem(
                caption: 'DISABLED · MIXED',
                child: KkCheckbox(value: null, tristate: true, label: 'interlock'),
              ),
              const SheetItem(
                caption: 'BARE',
                child: KkCheckbox(value: true, onChanged: _noopTristate, semanticLabel: 'Select row'),
              ),
            ],
          ),
          _Flow(
            gap: 48,
            children: <Widget>[
              SheetItem(
                caption: 'RADIO · COLUMN · ONE DISABLED',
                child: _Value<String>(
                  initial: 'manual',
                  builder: (BuildContext context, String value, ValueChanged<String> set) =>
                      KkRadioGroup<String>(options: _modes, value: value, onChanged: set, semanticLabel: 'Mode'),
                ),
              ),
              SheetItem(
                caption: 'RADIO · ROW',
                width: 420,
                child: _Value<String>(
                  initial: 'auto',
                  builder: (BuildContext context, String value, ValueChanged<String> set) => KkRadioGroup<String>(
                    options: _modes,
                    value: value,
                    onChanged: set,
                    direction: Axis.horizontal,
                    semanticLabel: 'Mode',
                  ),
                ),
              ),
              SheetItem(
                caption: 'HOVER',
                child: _hover(
                  const KkRadioGroup<String>(
                    options: <KkRadioOption<String>>[KkRadioOption<String>(value: 'a', label: 'bus a')],
                    value: null,
                    onChanged: _noopString,
                  ),
                ),
              ),
              SheetItem(
                caption: 'FOCUS',
                child: _focus(
                  const KkRadioGroup<String>(
                    options: <KkRadioOption<String>>[KkRadioOption<String>(value: 'a', label: 'bus a')],
                    value: 'a',
                    onChanged: _noopString,
                  ),
                ),
              ),
              const SheetItem(
                caption: 'DISABLED GROUP',
                child: KkRadioGroup<String>(
                  options: <KkRadioOption<String>>[
                    KkRadioOption<String>(value: 'a', label: 'bus a'),
                    KkRadioOption<String>(value: 'b', label: 'bus b'),
                  ],
                  value: 'a',
                ),
              ),
            ],
          ),
          _Flow(
            children: <Widget>[
              SheetItem(
                caption: 'SWITCH',
                child: _Value<bool>(
                  initial: true,
                  builder: (BuildContext context, bool value, ValueChanged<bool> set) =>
                      KkSwitch(value: value, label: 'aux power', cjk: '補助電源', onChanged: set),
                ),
              ),
              const SheetItem(
                caption: 'OFF',
                child: KkSwitch(value: false, label: 'audible alarm', onChanged: _noopBool),
              ),
              SheetItem(
                caption: 'FOCUS',
                child: _focus(const KkSwitch(value: true, label: 'coolant pump', onChanged: _noopBool)),
              ),
              const SheetItem(
                caption: 'CUSTOM WORDS',
                child: KkSwitch(
                  value: true,
                  offLabel: 'SAFE',
                  onLabel: 'ARMED',
                  label: 'interlock',
                  onChanged: _noopBool,
                ),
              ),
              const SheetItem(
                caption: 'DISABLED · OFF',
                child: KkSwitch(value: false, label: 'bus b'),
              ),
              const SheetItem(
                caption: 'DISABLED · ON',
                child: KkSwitch(value: true, label: 'bus b'),
              ),
              const SheetItem(
                caption: 'BARE',
                child: KkSwitch(value: false, onChanged: _noopBool, semanticLabel: 'Enable channel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-07 ────────────────────────────────────────────────────────────────

class _SliderSection extends StatelessWidget {
  const _SliderSection();

  static const List<KkSliderMark> _percentMarks = <KkSliderMark>[
    KkSliderMark(0, '0'),
    KkSliderMark(25, '25'),
    KkSliderMark(50, '50'),
    KkSliderMark(75, '75'),
    KkSliderMark(100, '100'),
  ];

  @override
  Widget build(BuildContext context) {
    return SheetSection(
      code: 'C-07',
      cjk: '調整',
      en: 'slider',
      child: _Flow(
        gap: 32,
        children: <Widget>[
          SheetItem(
            caption: 'HEAD · MARKS',
            width: 304,
            child: _Value<double>(
              initial: 62,
              builder: (BuildContext context, double value, ValueChanged<double> set) => KkSlider(
                value: value,
                cjk: '冷却流量',
                en: 'coolant flow',
                unit: '%',
                marks: _percentMarks,
                onChanged: set,
              ),
            ),
          ),
          SheetItem(
            caption: 'DIVISIONS 12 · −6 … +6',
            width: 304,
            child: _Value<double>(
              initial: 2,
              builder: (BuildContext context, double value, ValueChanged<double> set) => KkSlider(
                value: value,
                min: -6,
                max: 6,
                divisions: 12,
                cjk: '利得',
                en: 'gain',
                unit: 'dB',
                marks: const <KkSliderMark>[KkSliderMark(-6, '-6'), KkSliderMark(0, '0'), KkSliderMark(6, '+6')],
                onChanged: set,
              ),
            ),
          ),
          SheetItem(
            caption: 'HOVER',
            width: 200,
            child: _hover(const KkSlider(value: 38, en: 'threshold', onChanged: _noopDouble)),
          ),
          SheetItem(
            caption: 'FOCUS',
            width: 200,
            child: _focus(const KkSlider(value: 74, en: 'threshold', onChanged: _noopDouble)),
          ),
          const SheetItem(
            caption: 'DISABLED',
            width: 200,
            child: KkSlider(value: 50, cjk: '出力', en: 'output', unit: '%'),
          ),
          const SheetItem(
            caption: 'TRACK ONLY',
            width: 200,
            child: KkSlider(value: 20, showValue: false, onChanged: _noopDouble, semanticLabel: 'Volume'),
          ),
        ],
      ),
    );
  }
}

// ── C-08 ────────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    return const SheetSection(
      code: 'C-08',
      cjk: '進捗',
      en: 'progress · ring',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        cross: KkCrossAlign.start,
        children: <Widget>[
          _Flow(
            gap: 32,
            children: <Widget>[
              SheetItem(
                caption: 'SIGNAL',
                width: 240,
                child: KkProgress(value: 0.42, cjk: '転送', en: 'transfer'),
              ),
              SheetItem(
                caption: 'CAUTION',
                width: 240,
                child: KkProgress(value: 0.78, cjk: '負荷', en: 'load', level: KkLevel.caution),
              ),
              SheetItem(
                caption: 'CRITICAL',
                width: 240,
                child: KkProgress(value: 0.96, cjk: '容量', en: 'capacity', level: KkLevel.critical),
              ),
              SheetItem(
                caption: 'NOMINAL · FULL',
                width: 240,
                child: KkProgress(value: 1, cjk: '照合', en: 'checksum', level: KkLevel.nominal),
              ),
            ],
          ),
          _Flow(
            gap: 32,
            children: <Widget>[
              SheetItem(
                caption: 'INDETERMINATE',
                width: 240,
                child: KkProgress.indeterminate(cjk: '接続', en: 'handshake'),
              ),
              SheetItem(caption: 'BAR ONLY', width: 240, child: KkProgress(value: 0.3, showValue: false)),
              SheetItem(
                caption: 'ZERO',
                width: 240,
                child: KkProgress(value: 0, en: 'queue'),
              ),
              SheetItem(caption: 'RING · 25', child: KkRing(value: 0.25)),
              SheetItem(
                caption: 'CAUTION · 62',
                child: KkRing(value: 0.62, level: KkLevel.caution),
              ),
              SheetItem(
                caption: 'CRITICAL · 90',
                child: KkRing(value: 0.9, level: KkLevel.critical),
              ),
              SheetItem(
                caption: 'NOMINAL · FULL',
                child: KkRing(value: 1, level: KkLevel.nominal),
              ),
              SheetItem(caption: 'INDETERMINATE', child: KkRing.indeterminate()),
              SheetItem(caption: '32', child: KkRing(value: 0.5, size: 32, showValue: false)),
              SheetItem(
                caption: '64 · LABEL',
                child: KkRing(value: 0.7, size: 64, strokeWidth: 6, label: 'T-12'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-09 ────────────────────────────────────────────────────────────────

class _DividerSection extends StatelessWidget {
  const _DividerSection();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return SheetSection(
      code: 'C-09',
      cjk: '区切',
      en: 'divider',
      child: KkColumn(
        gap: 20,
        shrinkWrap: true,
        children: <Widget>[
          const KkDivider(),
          const KkDivider(code: 'SEC-04', cjk: '冷却', en: 'coolant'),
          const KkDivider(en: 'archive'),
          const KkDivider(ticks: true),
          const KkDivider(code: 'T+00:42', cjk: '経過', en: 'elapsed', ticks: true),
          KkRow(
            gap: 12,
            shrinkWrap: true,
            children: <Widget>[
              KkText.num('BUS A', size: 11, color: c.inkDim),
              const KkAlignSelf(align: KkCrossAlign.stretch, child: KkDivider.vertical()),
              KkText.num('BUS B', size: 11, color: c.inkDim),
              const KkDivider.vertical(height: 24),
              KkText.num('BUS C', size: 11, color: c.inkDim),
              const KkDivider.vertical(),
              KkText.num('VERTICAL · STRETCH / 24 / MIN 16', size: 10, color: c.inkFaint),
            ],
          ),
        ],
      ),
    );
  }
}

// ── C-10 ────────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  const _EmptySection();

  @override
  Widget build(BuildContext context) {
    return const SheetSection(
      code: 'C-10',
      cjk: '空白',
      en: 'skeleton · empty',
      child: _Flow(
        gap: 24,
        children: <Widget>[
          SheetItem(
            caption: 'SKELETON · LINES',
            width: 200,
            child: KkSkeleton(widths: <double>[1, 0.8, 0.55]),
          ),
          SheetItem(caption: 'SKELETON · BLOCK 96', width: 200, child: KkSkeleton.block(height: 96)),
          SheetItem(
            caption: 'EMPTY',
            width: 280,
            child: KkEmpty(cjk: '無記録', en: 'no records', sub: 'SEC-04 · 14:00Z TO 15:00Z · 0 EVENTS'),
          ),
          SheetItem(
            caption: 'EMPTY · LOADING · ACTION',
            width: 280,
            child: KkEmpty(
              cjk: '照会中',
              en: 'querying',
              loading: true,
              action: KkButton(label: 'cancel', size: KkButtonSize.sm, onPressed: _noop),
            ),
          ),
          SheetItem(
            caption: 'NO SIGNAL',
            width: 280,
            child: KkEmpty.noSignal(sub: 'CH.12 · LAST FRAME 14:02:31Z'),
          ),
        ],
      ),
    );
  }
}
