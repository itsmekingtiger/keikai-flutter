import 'package:keikai/keikai.dart';

import 'sheet_scaffold.dart';

String _hex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}

/// The foundations of KEIKAI: colour roles in both themes, the type scale,
/// measurement tokens, patterns, levels, the icon set and the stepped motion.
class FoundationSheet extends StatelessWidget {
  const FoundationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SheetScaffold(
      code: 'F-01',
      cjk: '基盤',
      en: 'foundation',
      note: '검은 바탕 위 신호 오렌지 프레임. 평시에는 오렌지, 경보 시에는 화면 전체가 적색으로 바뀐다.',
      sections: <Widget>[
        SheetSection(code: 'T-01', cjk: '色', en: 'colour · standby / alert', child: _Colours()),
        SheetSection(code: 'T-02', cjk: '文字', en: 'type scale', child: _TypeScale()),
        SheetSection(code: 'T-03', cjk: '寸法', en: 'space · stroke · chamfer', child: _Measures()),
        SheetSection(code: 'T-04', cjk: '模様', en: 'patterns', child: _Patterns()),
        SheetSection(code: 'T-05', cjk: '状態', en: 'levels', child: _Levels()),
        SheetSection(code: 'T-06', cjk: '図像', en: 'icons', child: _IconSet()),
        SheetSection(code: 'T-07', cjk: '動作', en: 'motion · stepped, no easing', child: _Motion()),
      ],
    );
  }
}

// ── colour ────────────────────────────────────────────────────────────────

class _Colours extends StatelessWidget {
  const _Colours();

  @override
  Widget build(BuildContext context) {
    return const KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        _Palette(condition: KkCondition.standby, cjk: '平時', en: 'standby'),
        _Palette(condition: KkCondition.alert, cjk: '警報', en: 'alert'),
      ],
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.condition, required this.cjk, required this.en});

  final KkCondition condition;
  final String cjk;
  final String en;

  @override
  Widget build(BuildContext context) {
    return KkConditionScope(
      condition: condition,
      child: Builder(
        builder: (BuildContext context) {
          final KkColors c = context.kk.colors;
          final List<(String, Color)> tokens = <(String, Color)>[
            ('bg-000', c.bg000),
            ('bg-100', c.bg100),
            ('bg-200', c.bg200),
            ('bg-300', c.bg300),
            ('line', c.line),
            ('grid', c.grid),
            ('ink', c.ink),
            ('ink-dim', c.inkDim),
            ('ink-faint', c.inkFaint),
            ('signal', c.signal),
            ('signal-dim', c.signalDim),
            ('nominal', c.nominal),
            ('caution', c.caution),
            ('alert', c.alert),
            ('alert-deep', c.alertDeep),
            ('offline', c.offline),
            ('on-fill', c.onFill),
            ('series-1', c.series1),
            ('series-2', c.series2),
            ('series-3', c.series3),
            ('focus', c.focus),
          ];
          return KkBox(
            decoration: KkDecoration(
              fill: c.bg000,
              edges: KkEdges.line(c.line),
              brackets: KkBracketSpec(color: c.signal),
            ),
            padding: const EdgeInsets.all(16),
            child: KkColumn(
              gap: 12,
              shrinkWrap: true,
              children: <Widget>[
                KkLabel(cjk: cjk, en: en, cjkSize: 21, enSize: 13),
                KkWrap(
                  gap: 8,
                  runGap: 12,
                  cross: KkCrossAlign.start,
                  children: <Widget>[
                    for (final (String name, Color color) in tokens) _Swatch(name: name, color: color),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkBox(
      width: 120,
      child: KkColumn(
        gap: 6,
        shrinkWrap: true,
        children: <Widget>[
          KkBox(height: 40, fill: color, edges: KkEdges.line(c.line)),
          KkText.num(name, size: 11, weight: FontWeight.w600, color: c.ink),
          KkText.num(_hex(color), size: 10, color: c.inkDim),
        ],
      ),
    );
  }
}

// ── type ──────────────────────────────────────────────────────────────────

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final KkTypography t = context.kk.type;
    final KkColors c = context.kk.colors;
    final List<(String, String, TextStyle, String)> rows = <(String, String, TextStyle, String)>[
      ('display-xl', '72 / 0.95 · 900', t.displayXl, '冷却系統 異常'),
      ('display-lg', '44 / 1.0 · 900', t.displayLg, '電源系統 · 전원 계통'),
      ('display-md', '24 / 1.1 · 900', t.displayMd, '通信回線'),
      ('display-sm', '17 / 1.15 · 900', t.displaySm, '接続状態'),
      ('label-xl', '32 / 1.0 · 800', t.labelXl, 'CRITICAL — COOLANT PRESSURE LOW'),
      ('label-lg', '20 / 1.1 · 700', t.labelLg, 'AUXILIARY POWER ONLINE'),
      ('label-md', '13 / 1.2 · 700', t.labelMd, 'SYSTEM STATUS'),
      ('label-sm', '11 / 1.2 · 600', t.labelSm, 'SEC-04 · CH.12 · UTC'),
      ('readout-xl', '56 / 1.0 · 500', t.readoutXl, '04:59.82'),
      ('readout', '32 / 1.0 · 500', t.readout, '042.7'),
      ('data', '12 / 1.5 · 400', t.data, '14:02:31.004Z  SEC-04  ACK  0x3F'),
      ('body', '14 / 1.55 · 400', t.bodyMd, '냉각수 압력이 기준치 아래로 떨어졌습니다. 보조 펌프를 기동하십시오.'),
      ('body-sm', '12 / 1.5 · 400', t.bodySm, '마지막 점검 2026-11-24 09:00Z · 담당 OP-07'),
    ];
    return KkColumn(
      shrinkWrap: true,
      children: <Widget>[
        for (final (String name, String spec, TextStyle style, String sample) in rows)
          KkBox(
            padding: const EdgeInsets.symmetric(vertical: 10),
            edges: KkEdges(bottom: KkSide(c.bg200)),
            child: KkRow(
              gap: 24,
              cross: KkCrossAlign.baseline,
              children: <Widget>[
                KkBox(
                  width: 112,
                  child: KkText.num(name, size: 11, weight: FontWeight.w600, color: c.signal),
                ),
                KkBox(
                  width: 136,
                  child: KkText.num(spec, size: 10, color: c.inkFaint),
                ),
                KkExpanded(
                  child: KkText(sample, style: style, color: c.ink, maxLines: 1, softWrap: false),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── measures ──────────────────────────────────────────────────────────────

class _Measures extends StatelessWidget {
  const _Measures();

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = context.kk.metrics;
    final KkColors c = context.kk.colors;
    final List<(String, double)> spaces = <(String, double)>[
      ('space-1', m.space1),
      ('space-2', m.space2),
      ('space-3', m.space3),
      ('space-4', m.space4),
      ('space-6', m.space6),
      ('space-8', m.space8),
      ('space-12', m.space12),
    ];
    final List<(String, double)> strokes = <(String, double)>[
      ('stroke-1', m.stroke1),
      ('stroke-2', m.stroke2),
      ('stroke-4', m.stroke4),
    ];
    final List<(String, double)> chamfers = <(String, double)>[
      ('chamfer-sm', m.chamferSm),
      ('chamfer-md', m.chamferMd),
      ('chamfer-lg', m.chamferLg),
    ];
    return KkRow(
      gap: 48,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkColumn(
          gap: 8,
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            for (final (String name, double v) in spaces)
              KkRow(
                gap: 12,
                shrinkWrap: true,
                children: <Widget>[
                  KkBox(
                    width: 72,
                    child: KkText.num(name, size: 11, weight: FontWeight.w600, color: c.ink),
                  ),
                  KkBox(
                    width: 40,
                    child: KkText.num('${v.round()}px', size: 10, color: c.inkDim),
                  ),
                  KkBox(width: v, height: 12, fill: c.signal),
                ],
              ),
          ],
        ),
        KkColumn(
          gap: 12,
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            for (final (String name, double v) in strokes)
              KkRow(
                gap: 12,
                shrinkWrap: true,
                children: <Widget>[
                  KkBox(
                    width: 72,
                    child: KkText.num(name, size: 11, weight: FontWeight.w600, color: c.ink),
                  ),
                  KkBox(
                    width: 40,
                    child: KkText.num('${v.round()}px', size: 10, color: c.inkDim),
                  ),
                  KkBox(width: 160, height: v, fill: c.signal),
                ],
              ),
          ],
        ),
        KkRow(
          gap: 16,
          shrinkWrap: true,
          cross: KkCrossAlign.start,
          children: <Widget>[
            for (final (String name, double v) in chamfers)
              KkColumn(
                gap: 8,
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkSurface(
                    shape: KkShape.plate(v),
                    edge: c.signal,
                    fill: c.bg100,
                    child: const KkBox(width: 96, height: 48),
                  ),
                  KkText.num(name, size: 11, weight: FontWeight.w600, color: c.ink),
                  KkText.num('${v.round()}px · 45°', size: 10, color: c.inkDim),
                ],
              ),
            KkColumn(
              gap: 8,
              shrinkWrap: true,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkSurface(
                  shape: KkShape.slant(m.chamferLg),
                  fill: c.signal,
                  child: KkBox(
                    height: 32,
                    padding: EdgeInsets.fromLTRB(m.space3, 0, m.space2 + m.chamferLg, 0),
                    alignment: Alignment.center,
                    child: KkText.num('SEC-04', size: 11, weight: FontWeight.w600, spacing: 0.06, color: c.onFill),
                  ),
                ),
                KkText.num('code block', size: 11, weight: FontWeight.w600, color: c.ink),
                KkText.num('slant chamfer-lg', size: 10, color: c.inkDim),
              ],
            ),
            KkColumn(
              gap: 8,
              shrinkWrap: true,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkBox(
                  width: 96,
                  height: 48,
                  decoration: KkDecoration(
                    fill: c.bg100,
                    edges: KkEdges.line(c.line),
                    brackets: KkBracketSpec(color: c.signal),
                  ),
                ),
                KkText.num('brackets', size: 11, weight: FontWeight.w600, color: c.ink),
                KkText.num('12px · stroke-2', size: 10, color: c.inkDim),
              ],
            ),
            KkColumn(
              gap: 8,
              shrinkWrap: true,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkBox(
                  width: 96,
                  height: 48,
                  decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.signal), glow: c.glowSignal),
                ),
                KkText.num('glow-signal', size: 11, weight: FontWeight.w600, color: c.ink),
                KkText.num('ring 1 · blur 18', size: 10, color: c.inkDim),
              ],
            ),
            KkColumn(
              gap: 8,
              shrinkWrap: true,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkBox(
                  width: 96,
                  height: 48,
                  decoration: KkDecoration(fill: c.bg100, edges: KkEdges.line(c.alert), glow: c.glowAlert),
                ),
                KkText.num('glow-alert', size: 11, weight: FontWeight.w600, color: c.ink),
                KkText.num('ring 1 · blur 22', size: 10, color: c.inkDim),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── patterns ──────────────────────────────────────────────────────────────

class _Patterns extends StatelessWidget {
  const _Patterns();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final KkMetrics m = context.kk.metrics;
    final List<(String, String, KkDecoration)> items = <(String, String, KkDecoration)>[
      (
        'grid',
        'pitch 24',
        KkDecoration(fill: c.bg000, pattern: KkPattern.grid(color: c.grid, pitch: m.pitchGrid)),
      ),
      (
        'fine grid',
        'pitch 8',
        KkDecoration(fill: c.bg000, pattern: KkPattern.grid(color: c.grid, pitch: m.pitchFine)),
      ),
      (
        'plot',
        'fine + major',
        KkDecoration(fill: c.bg000, pattern: KkPattern.plot(minor: c.grid, major: c.signalDim)),
      ),
      (
        'hazard',
        'pitch 12 · 45°',
        KkDecoration(pattern: KkPattern.stripes(a: c.signal, b: c.bg000, width: m.pitchHazard)),
      ),
      (
        'hazard critical',
        'runs at 0.9s',
        KkDecoration(pattern: KkPattern.stripes(a: c.alert, b: c.bg000, width: m.pitchHazard)),
      ),
      (
        'hex field',
        '20% max',
        KkDecoration(fill: c.bg000, pattern: KkPattern.hex(color: c.alert, pitch: m.pitchGrid)),
      ),
      (
        'offline hatch',
        '3px stripes',
        KkDecoration(pattern: KkPattern.stripes(a: c.bg100, b: c.bg200, width: 3)),
      ),
      (
        'scan lines',
        'over displays',
        KkDecoration(fill: c.bg300, overlay: KkPattern.scanlines(color: kkFade(c.bg000, 0.5))),
      ),
    ];
    return KkWrap(
      gap: 16,
      runGap: 16,
      cross: KkCrossAlign.start,
      children: <Widget>[
        for (final (String name, String spec, KkDecoration decoration) in items)
          KkColumn(
            gap: 8,
            shrinkWrap: true,
            cross: KkCrossAlign.start,
            children: <Widget>[
              KkBox(
                edges: KkEdges.line(c.line),
                child: KkBox(width: 152, height: 72, decoration: decoration),
              ),
              KkText.num(name, size: 11, weight: FontWeight.w600, color: c.ink),
              KkText.num(spec, size: 10, color: c.inkDim),
            ],
          ),
      ],
    );
  }
}

// ── levels ────────────────────────────────────────────────────────────────

class _Levels extends StatelessWidget {
  const _Levels();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkWrap(
      gap: 16,
      runGap: 16,
      children: <Widget>[
        for (final KkLevel? level in const <KkLevel?>[
          KkLevel.nominal,
          KkLevel.caution,
          KkLevel.critical,
          KkLevel.offline,
          null,
        ])
          KkBox(
            width: 256,
            padding: const EdgeInsets.all(12),
            decoration: KkDecoration(
              fill: c.bg100,
              edges: KkEdges(
                top: KkSide(level == null ? c.inkDim : c.level(level), width: 2),
                right: KkSide(c.line),
                bottom: KkSide(c.line),
                left: KkSide(c.line),
              ),
            ),
            child: KkRow(
              gap: 12,
              children: <Widget>[
                KkGlyph(level: level, size: 32, color: level == null ? c.inkDim : null),
                KkColumn(
                  gap: 6,
                  shrinkWrap: true,
                  cross: KkCrossAlign.start,
                  children: <Widget>[
                    KkRow(
                      gap: 8,
                      shrinkWrap: true,
                      cross: KkCrossAlign.baseline,
                      children: <Widget>[
                        KkText.en(
                          level?.word ?? 'info',
                          size: 15,
                          spacing: 0.12,
                          color: level == null ? c.inkDim : c.level(level),
                        ),
                        if (level != null) KkText.cjk(level.cjk, size: 15, color: c.level(level)),
                      ],
                    ),
                    KkText.num(
                      level == null ? 'no level · 수준 없음' : '${level.name} · ${level.ko}',
                      size: 10,
                      color: c.inkDim,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── icons ─────────────────────────────────────────────────────────────────

class _IconSet extends StatelessWidget {
  const _IconSet();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkWrap(
      gap: 4,
      runGap: 12,
      cross: KkCrossAlign.start,
      children: <Widget>[
        for (final KkIconData icon in KkIcons.values)
          KkBox(
            width: 88,
            child: KkColumn(
              gap: 6,
              shrinkWrap: true,
              cross: KkCrossAlign.center,
              children: <Widget>[
                KkBox(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  fill: c.bg100,
                  edges: KkEdges.line(c.line),
                  child: KkIcon(icon, size: 16, color: c.ink),
                ),
                KkText.num(icon.name, size: 9, color: c.inkDim, textAlign: TextAlign.center),
              ],
            ),
          ),
      ],
    );
  }
}

// ── motion ────────────────────────────────────────────────────────────────

class _Motion extends StatelessWidget {
  const _Motion();

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 24,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        _Strip(
          name: 'boot wipe',
          spec: '0.42s · steps(7)',
          frames: <Widget>[
            for (int i = 0; i <= KkMotion.bootSteps; i++)
              _Specimen(reveal: i / KkMotion.bootSteps, caption: '${i * 60}ms'),
          ],
        ),
        _Strip(
          name: 'flicker',
          spec: '0.50s · steps(10)',
          frames: <Widget>[
            for (final double t in const <double>[0.0, 0.1, 0.2, 0.25, 0.3, 0.45, 0.5, 0.55, 0.7])
              _Specimen(
                opacity: KkKeyframes.flicker.transform(t),
                caption: '${(t * 500).round()}ms',
              ),
          ],
        ),
        _Strip(
          name: 'scramble',
          spec: '0.46s · settles from the front',
          frames: <Widget>[
            for (int i = 0; i <= 5; i++)
              KkColumn(
                gap: 6,
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkBox(
                    width: 132,
                    height: 44,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    fill: c.bg100,
                    edges: KkEdges(
                      top: KkSide(c.nominal, width: 2),
                      right: KkSide(c.line),
                      bottom: KkSide(c.line),
                      left: KkSide(c.line),
                    ),
                    child: KkText.num(
                      kkScrambleText('042.7', i / 5, step: i * 2, seed: 4),
                      size: 24,
                      weight: FontWeight.w500,
                      color: c.nominal,
                    ),
                  ),
                  KkText.num('${(i * 92)}ms', size: 9, color: c.inkFaint),
                ],
              ),
          ],
        ),
        _Strip(
          name: 'strobe',
          spec: '1.2s · steps(1) · critical only',
          frames: <Widget>[
            for (int i = 0; i < 4; i++)
              KkColumn(
                gap: 6,
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkBox(
                    width: 132,
                    height: 44,
                    alignment: Alignment.center,
                    fill: i.isEven ? c.alert : c.alertDeep,
                    child: KkText.en('critical', size: 15, spacing: 0.12, color: i.isEven ? c.onFill : c.ink),
                  ),
                  KkText.num('${i * 600}ms', size: 9, color: c.inkFaint),
                ],
              ),
          ],
        ),
        _Strip(
          name: 'hazard run',
          spec: '0.9s · linear · one period',
          frames: <Widget>[
            for (int i = 0; i < 6; i++)
              KkColumn(
                gap: 6,
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                children: <Widget>[
                  KkBox(
                    width: 132,
                    height: 24,
                    decoration: KkDecoration(
                      pattern: KkPattern.stripes(
                        a: c.alert,
                        b: c.bg000,
                        width: 12,
                        shift: i * 33.94 / 6,
                        tiled: true,
                      ),
                    ),
                  ),
                  KkText.num('${i * 150}ms', size: 9, color: c.inkFaint),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.name, required this.spec, required this.frames});

  final String name;
  final String spec;
  final List<Widget> frames;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkRow(
      gap: 24,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkBox(
          width: 200,
          child: KkColumn(
            gap: 6,
            shrinkWrap: true,
            children: <Widget>[
              KkText.en(name, size: 13, spacing: 0.1, color: c.ink),
              KkText.num(spec, size: 10, color: c.inkDim),
            ],
          ),
        ),
        KkExpanded(
          child: KkWrap(gap: 8, runGap: 8, cross: KkCrossAlign.start, children: frames),
        ),
      ],
    );
  }
}

/// A miniature panel drawn at one instant of an entrance: [reveal] is how much
/// of it the wipe has uncovered, [opacity] how bright the flicker is.
class _Specimen extends StatelessWidget {
  const _Specimen({this.reveal = 1, this.opacity = 1, required this.caption});

  final double reveal;
  final double opacity;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    const double w = 120;
    const double h = 56;
    Color f(Color color) => kkFade(color, opacity);
    return KkColumn(
      gap: 6,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        KkBox(
          width: w,
          height: h,
          edges: KkEdges.line(c.bg200, dashed: true),
          child: KkLayers(
            clip: Clip.hardEdge,
            children: <Widget>[
              KkPositioned(
                left: 0,
                top: 0,
                width: w * reveal,
                height: h,
                child: KkLayers(
                  clip: Clip.hardEdge,
                  children: <Widget>[
                    KkPositioned(
                      left: 0,
                      top: 0,
                      width: w,
                      height: h,
                      child: KkBox(
                        decoration: KkDecoration(fill: f(c.bg100), edges: KkEdges.line(f(c.line))),
                        child: KkColumn(
                          children: <Widget>[
                            KkBox(height: 14, fill: f(c.signal)),
                            KkBox(
                              padding: const EdgeInsets.all(8),
                              child: KkColumn(
                                gap: 5,
                                shrinkWrap: true,
                                cross: KkCrossAlign.start,
                                children: <Widget>[
                                  KkBox(width: 72, height: 6, fill: f(c.ink)),
                                  KkBox(width: 48, height: 6, fill: f(c.inkFaint)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        KkText.num(caption, size: 9, color: c.inkFaint),
      ],
    );
  }
}
