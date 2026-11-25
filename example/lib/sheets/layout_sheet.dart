import 'package:keikai/keikai.dart';
// ignore: implementation_imports
import 'package:keikai/src/layout/layout.dart';

import 'sheet_scaffold.dart';

/// The catalogue sheet of the layout system: the panel grid at three widths,
/// the screen skeleton at its three arrangements, flex alignment, wrap,
/// layers, split panes and the window classes.
class LayoutSheet extends StatelessWidget {
  const LayoutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-02',
      cjk: '配置',
      en: 'layout',
      note: '4px 그리드. 패널은 8px 거터로 빽빽하게 타일링하고 행 단위는 48px. 열 수와 화면 배치는 창이 아니라 자기 폭을 따른다.',
      sections: <Widget>[
        _GridSection(),
        _ScreenSection(),
        _FlexSection(),
        _WrapLayersSection(),
        _SplitSection(),
        _BreakpointSection(),
      ],
    );
  }
}

// ── shared specimens ────────────────────────────────────────────────────────

/// A small filled block: one child of a flex specimen.
class _Block extends StatelessWidget {
  const _Block({this.width, this.height, this.label});

  final double? width;
  final double? height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final String? text = label;
    return KkBox(
      width: width,
      height: height,
      alignment: text == null ? null : Alignment.center,
      decoration: KkDecoration(fill: c.signalDim, edges: KkEdges.line(c.signal)),
      child: text == null ? null : KkText.num(text, size: 10, weight: FontWeight.w500, color: c.ink),
    );
  }
}

/// The track a specimen is laid out in.
class _Track extends StatelessWidget {
  const _Track({this.height, this.padding = const EdgeInsets.all(4), required this.child});

  final double? height;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkBox(
      height: height,
      padding: padding,
      decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
      child: child,
    );
  }
}

/// A small outlined mono tag.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkBox(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      shrinkWrap: true,
      decoration: KkDecoration(fill: c.bg200, edges: KkEdges.line(active ? c.signal : c.inkFaint)),
      child: KkText.num(text, size: 11, weight: FontWeight.w500, color: active ? c.signal : c.ink),
    );
  }
}

/// A labelled region of a miniature screen or split.
class _Slot extends StatelessWidget {
  const _Slot({this.cjk, required this.en, this.width, this.height, this.note, this.vertical = false});

  final String? cjk;
  final String en;
  final double? width;
  final double? height;
  final String? note;

  /// Set the CJK title upright (for a narrow rail).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final String? n = note;
    final String? title = cjk;
    return KkBox(
      width: width,
      height: height,
      alignment: Alignment.center,
      clip: true,
      decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
      child: vertical
          ? KkColumn(
              shrinkWrap: true,
              gap: 8,
              cross: KkCrossAlign.center,
              children: <Widget>[
                if (title != null) KkTate(title, size: 14, color: c.ink),
                KkText.en(en, size: 10, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
              ],
            )
          : KkColumn(
              shrinkWrap: true,
              gap: 6,
              cross: KkCrossAlign.center,
              children: <Widget>[
                KkLabel(cjk: title, en: en, cjkSize: 14, enSize: 11),
                if (n != null) KkText.num(n, size: 10, color: c.inkFaint),
              ],
            ),
    );
  }
}

// ── L-01 grid ───────────────────────────────────────────────────────────────

class _GridSection extends StatelessWidget {
  const _GridSection();

  @override
  Widget build(BuildContext context) {
    return SheetSection(
      code: 'L-01',
      cjk: '格子',
      en: 'grid',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        children: <Widget>[
          KkText.body(
            '같은 여덟 칸을 세 가지 폭에 놓았다. 뒤에 오는 작은 칸은 앞선 칸이 남긴 빈자리로 올라가고(05 · 07), 열보다 넓은 칸은 열 수에 맞춰 줄어든다(06).',
            size: 12,
            height: 1.5,
            color: context.kk.colors.inkDim,
          ),
          const KkRow(
            gap: 24,
            cross: KkCrossAlign.start,
            children: <Widget>[
              SheetItem(caption: 'WIDTH 360 · 4 COLUMNS · BELOW 600', width: 360, child: _GridSpecimen()),
              SheetItem(caption: 'WIDTH 720 · 8 COLUMNS · FROM 600', width: 720, child: _GridSpecimen()),
            ],
          ),
          const SheetItem(caption: 'FULL WIDTH · 12 COLUMNS · FROM 840', child: _GridSpecimen()),
        ],
      ),
    );
  }
}

/// Eight numbered cells over the column tracks of the grid they are in.
class _GridSpecimen extends StatelessWidget {
  const _GridSpecimen();

  /// Column span and row count of each cell.
  static const List<(int, int)> _cells = <(int, int)>[(4, 2), (2, 1), (2, 2), (4, 1), (2, 1), (6, 1), (2, 1), (3, 1)];

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = context.kk;
    final KkColors c = theme.colors;
    return KkBreakpoint(
      builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
        final int columns = theme.metrics.columnsFor(constraints.maxWidth);
        return KkLayers(
          children: <Widget>[
            // The column tracks, visible wherever no cell covers them.
            KkPositioned.fill(
              child: KkRow(
                gap: theme.metrics.gridGutter,
                cross: KkCrossAlign.stretch,
                children: <Widget>[
                  for (int i = 0; i < columns; i++) KkExpanded(child: KkBox(fill: c.grid)),
                ],
              ),
            ),
            KkGrid(
              children: <Widget>[
                for (int i = 0; i < _cells.length; i++)
                  KkCell(
                    span: _cells[i].$1,
                    rows: _cells[i].$2,
                    child: _GridCell(index: i + 1, span: _cells[i].$1, rows: _cells[i].$2),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.index, required this.span, required this.rows});

  final int index;
  final int span;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkBox(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clip: true,
      decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.line)),
      child: KkRow(
        gap: 8,
        cross: KkCrossAlign.start,
        clip: Clip.hardEdge,
        children: <Widget>[
          KkText.num(index < 10 ? '0$index' : '$index', size: 13, weight: FontWeight.w600, color: c.signal),
          KkText.num('$span × $rows', size: 10, height: 1.3, color: c.inkFaint),
        ],
      ),
    );
  }
}

// ── L-02 screen ─────────────────────────────────────────────────────────────

class _ScreenSection extends StatelessWidget {
  const _ScreenSection();

  @override
  Widget build(BuildContext context) {
    return const SheetSection(
      code: 'L-02',
      cjk: '画面骨格',
      en: 'screen',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        children: <Widget>[
          SheetItem(
            caption: 'FULL WIDTH · 840 AND WIDER · NAV | BODY | SIDE · MARGIN 16',
            child: _MiniScreen(height: 264),
          ),
          KkRow(
            gap: 24,
            cross: KkCrossAlign.start,
            children: <Widget>[
              SheetItem(
                caption: 'WIDTH 720 · 600 TO 839 · SIDE UNDER BODY · MARGIN 16',
                width: 720,
                child: _MiniScreen(height: 336),
              ),
              SheetItem(
                caption: 'WIDTH 400 · BELOW 600 · NAV AS A BOTTOM BAR · MARGIN 8',
                width: 400,
                child: _MiniScreen(height: 336),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A [KkScreen] with a labelled box in every region.
class _MiniScreen extends StatelessWidget {
  const _MiniScreen({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = context.kk;
    return KkBox(
      height: height,
      edges: KkEdges.line(theme.colors.line),
      child: KkScreen(
        safeArea: false,
        scrollBody: false,
        commandBar: _Slot(cjk: '指令帯', en: 'command bar', height: theme.metrics.cmdbarHeight),
        nav: const _MiniNav(),
        body: const _MiniBody(),
        side: const _MiniSide(),
        footer: _Slot(en: 'toolbar', height: theme.metrics.toolbarHeight),
      ),
    );
  }
}

class _MiniNav extends StatelessWidget {
  const _MiniNav();

  @override
  Widget build(BuildContext context) {
    // A rail on the side; a bar across the bottom once the screen is compact.
    if (KkScreenScope.of(context).navIsBar) return const _Slot(cjk: '航法', en: 'nav bar', height: 64);
    return _Slot(cjk: '航法', en: 'rail', width: context.kk.metrics.railWidth, vertical: true);
  }
}

class _MiniSide extends StatelessWidget {
  const _MiniSide();

  @override
  Widget build(BuildContext context) {
    if (KkScreenScope.of(context).sideIsStacked) return const _Slot(cjk: '側面', en: 'side', height: 56);
    return const _Slot(cjk: '側面', en: 'side', width: 208);
  }
}

class _MiniBody extends StatelessWidget {
  const _MiniBody();

  @override
  Widget build(BuildContext context) {
    final KkScreenData data = KkScreenScope.of(context);
    return _Slot(
      cjk: '本文',
      en: 'body',
      note: 'CLASS ${data.windowClass.name.toUpperCase()} · W ${data.width.round().toString().padLeft(4, '0')}',
    );
  }
}

// ── L-03 flex ───────────────────────────────────────────────────────────────

class _FlexSection extends StatelessWidget {
  const _FlexSection();

  static const List<(KkMainAlign, String)> _main = <(KkMainAlign, String)>[
    (KkMainAlign.start, 'MAIN · START'),
    (KkMainAlign.center, 'MAIN · CENTER'),
    (KkMainAlign.end, 'MAIN · END'),
    (KkMainAlign.between, 'MAIN · BETWEEN'),
    (KkMainAlign.around, 'MAIN · AROUND'),
    (KkMainAlign.evenly, 'MAIN · EVENLY'),
  ];

  static const List<(KkCrossAlign, String)> _cross = <(KkCrossAlign, String)>[
    (KkCrossAlign.start, 'CROSS · START'),
    (KkCrossAlign.center, 'CROSS · CENTER'),
    (KkCrossAlign.end, 'CROSS · END'),
    (KkCrossAlign.stretch, 'CROSS · STRETCH'),
  ];

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return SheetSection(
      code: 'L-03',
      cjk: '行列',
      en: 'row · column',
      child: KkColumn(
        gap: 24,
        shrinkWrap: true,
        children: <Widget>[
          KkWrap(
            gap: 24,
            runGap: 16,
            cross: KkCrossAlign.start,
            children: <Widget>[
              for (final (KkMainAlign align, String caption) in _main)
                SheetItem(
                  caption: caption,
                  width: 208,
                  child: _Track(
                    height: 32,
                    child: KkRow(
                      main: align,
                      gap: 4,
                      children: const <Widget>[
                        _Block(width: 24, height: 16),
                        _Block(width: 40, height: 16),
                        _Block(width: 16, height: 16),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          KkWrap(
            gap: 24,
            runGap: 16,
            cross: KkCrossAlign.start,
            children: <Widget>[
              for (final (KkCrossAlign align, String caption) in _cross)
                SheetItem(
                  caption: caption,
                  width: 208,
                  child: _Track(
                    height: 56,
                    child: KkRow(
                      cross: align,
                      gap: 4,
                      children: <Widget>[
                        _Block(width: 32, height: align == KkCrossAlign.stretch ? null : 16),
                        _Block(width: 32, height: align == KkCrossAlign.stretch ? null : 40),
                        _Block(width: 32, height: align == KkCrossAlign.stretch ? null : 24),
                      ],
                    ),
                  ),
                ),
              SheetItem(
                caption: 'CROSS · BASELINE',
                width: 208,
                child: _Track(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: KkRow(
                    cross: KkCrossAlign.baseline,
                    gap: 8,
                    children: <Widget>[
                      KkText.cjk('電源', size: 28, squeeze: 0.8, color: c.ink),
                      KkText.en('power', size: 13, color: c.inkDim),
                      KkText.num('042', size: 20, weight: FontWeight.w500, color: c.nominal),
                    ],
                  ),
                ),
              ),
              const SheetItem(
                caption: 'COLUMN · GAP 4 · STRETCH',
                width: 208,
                child: _Track(
                  height: 56,
                  child: KkColumn(
                    gap: 4,
                    children: <Widget>[
                      _Block(height: 12),
                      KkExpanded(child: _Block()),
                      _Block(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SheetItem(
            caption: 'SHARES · FIXED 72 · FLEX 1 · FLEX 2 · FIXED 120 · GAP 8',
            width: 720,
            child: _Track(
              height: 40,
              child: KkRow(
                gap: 8,
                cross: KkCrossAlign.stretch,
                children: <Widget>[
                  _Block(width: 72, label: '72'),
                  KkExpanded(child: _Block(label: 'FLEX 1')),
                  KkExpanded(flex: 2, child: _Block(label: 'FLEX 2')),
                  _Block(width: 120, label: '120'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── L-04 wrap · layers ──────────────────────────────────────────────────────

class _WrapLayersSection extends StatelessWidget {
  const _WrapLayersSection();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return SheetSection(
      code: 'L-04',
      cjk: '折返 · 重層',
      en: 'wrap · layers',
      child: KkRow(
        gap: 24,
        cross: KkCrossAlign.start,
        children: <Widget>[
          SheetItem(
            caption: 'WRAP · WIDTH 416 · GAP 8',
            width: 416,
            child: _Track(
              padding: const EdgeInsets.all(8),
              child: KkWrap(
                gap: 8,
                children: <Widget>[
                  for (int i = 1; i <= 14; i++) _Chip('SEC-${i < 10 ? '0$i' : '$i'}', active: i == 4),
                ],
              ),
            ),
          ),
          SheetItem(
            caption: 'WRAP · BETWEEN',
            width: 304,
            child: _Track(
              padding: const EdgeInsets.all(8),
              child: KkWrap(
                gap: 8,
                main: KkMainAlign.between,
                children: <Widget>[
                  for (final String ch in const <String>['CH.01', 'CH.02', 'CH.03', 'CH.04', 'CH.05', 'CH.06', 'CH.07'])
                    _Chip(ch),
                ],
              ),
            ),
          ),
          SheetItem(
            caption: 'LAYERS · PINNED TO EDGES · ONE CENTRED',
            width: 416,
            child: KkBox(
              height: 136,
              edges: KkEdges.line(c.line),
              child: const KkLayers(
                children: <Widget>[
                  KkPositioned.fill(child: KkBackdrop(kind: KkBackdropKind.plot)),
                  KkPositioned(left: 8, top: 8, child: _Chip('LEFT 8 · TOP 8')),
                  KkPositioned(right: 8, top: 8, child: _Chip('RIGHT 8 · TOP 8')),
                  KkPositioned(left: 8, right: 8, bottom: 8, height: 22, child: _Chip('LEFT 8 · RIGHT 8 · BOTTOM 8')),
                  KkLayerAlign(alignment: Alignment.center, child: _Chip('CENTER', active: true)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── L-05 split ──────────────────────────────────────────────────────────────

class _SplitSection extends StatelessWidget {
  const _SplitSection();

  @override
  Widget build(BuildContext context) {
    return const SheetSection(
      code: 'L-05',
      cjk: '分割',
      en: 'split',
      child: KkRow(
        gap: 24,
        cross: KkCrossAlign.start,
        children: <Widget>[
          SheetItem(
            caption: 'HORIZONTAL · RATIO .30 · HANDLE 8 · DRAG OR ARROW KEYS',
            width: 720,
            child: KkBox(
              height: 160,
              child: KkSplit(
                initialRatio: 0.3,
                minFirst: 96,
                minSecond: 160,
                semanticLabel: 'Log width',
                first: _Slot(cjk: '記録', en: 'log', note: 'MIN 96'),
                second: _Slot(cjk: '詳細', en: 'detail', note: 'MIN 160'),
              ),
            ),
          ),
          SheetItem(
            caption: 'VERTICAL · RATIO .60',
            width: 304,
            child: KkBox(
              height: 160,
              child: KkSplit(
                axis: Axis.vertical,
                initialRatio: 0.6,
                semanticLabel: 'Trace height',
                first: _Slot(cjk: '波形', en: 'trace'),
                second: _Slot(en: 'spectrum'),
              ),
            ),
          ),
          SheetItem(
            caption: 'FIXED DIVIDER',
            width: 304,
            child: KkBox(
              height: 160,
              child: KkSplit(
                enabled: false,
                initialRatio: 0.5,
                first: _Slot(cjk: '主系', en: 'primary'),
                second: _Slot(cjk: '副系', en: 'backup'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── L-06 window classes ─────────────────────────────────────────────────────

class _BreakpointSection extends StatelessWidget {
  const _BreakpointSection();

  /// The smallest width of each class, read from the theme.
  static double _from(KkMetrics m, KkWindowClass c) => switch (c) {
    KkWindowClass.compact => 0,
    KkWindowClass.medium => m.bpMedium,
    KkWindowClass.expanded => m.bpExpanded,
    KkWindowClass.large => m.bpLarge,
    KkWindowClass.xlarge => m.bpXlarge,
    KkWindowClass.wall => m.bpWall,
  };

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = context.kk;
    final KkMetrics m = theme.metrics;
    final KkColors c = theme.colors;
    return SheetSection(
      code: 'L-06',
      cjk: '区分',
      en: 'window classes',
      child: KkWrap(
        gap: 24,
        runGap: 16,
        cross: KkCrossAlign.start,
        children: <Widget>[
          for (final KkWindowClass windowClass in KkWindowClass.values)
            KkBox(
              width: 208,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: KkDecoration(
                fill: c.bg100,
                edges: KkEdges(
                  top: KkSide(c.signal, width: 2),
                  right: KkSide(c.line),
                  bottom: KkSide(c.line),
                  left: KkSide(c.line),
                ),
              ),
              child: KkColumn(
                gap: 8,
                shrinkWrap: true,
                children: <Widget>[
                  KkText.en(windowClass.name, size: 13, color: c.ink),
                  KkText.num(
                    _from(m, windowClass) == 0 ? '0000 PX' : '${_from(m, windowClass).round().toString().padLeft(4, '0')} PX',
                    size: 20,
                    weight: FontWeight.w500,
                    color: c.ink,
                  ),
                  KkRow(
                    main: KkMainAlign.between,
                    children: <Widget>[
                      KkText.num(
                        '${m.columnsFor(_from(m, windowClass)).toString().padLeft(2, '0')} COL',
                        size: 11,
                        color: c.inkDim,
                      ),
                      KkText.num(
                        'MARGIN ${m.marginFor(_from(m, windowClass)).round().toString().padLeft(2, '0')}',
                        size: 11,
                        color: c.inkDim,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
