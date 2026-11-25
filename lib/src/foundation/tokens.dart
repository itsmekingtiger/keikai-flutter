import 'package:flutter/foundation.dart';

/// Window size classes. The grid and the screen skeleton switch on these.
///
/// The thresholds are the design system's breakpoints: medium 600, expanded
/// 840, large 1200, xlarge 1600, wall 2560.
enum KkWindowClass { compact, medium, expanded, large, xlarge, wall }

/// The measurement tokens of KEIKAI: the 4px spacing grid, the three stroke
/// weights, chamfer sizes, pattern pitches, skeleton dimensions and breakpoints.
///
/// Every widget reads its sizes from the ambient theme's [KkMetrics], so a
/// whole app can be re-proportioned by handing a different instance to
/// `KeikaiThemeData.metrics`.
@immutable
class KkMetrics {
  const KkMetrics({
    this.space1 = 4,
    this.space2 = 8,
    this.space3 = 12,
    this.space4 = 16,
    this.space6 = 24,
    this.space8 = 32,
    this.space12 = 48,
    this.stroke1 = 1,
    this.stroke2 = 2,
    this.stroke4 = 4,
    this.chamferSm = 6,
    this.chamferMd = 10,
    this.chamferLg = 14,
    this.pitchFine = 8,
    this.pitchGrid = 24,
    this.pitchHazard = 12,
    this.pitchHex = 64,
    this.gridGutter = 8,
    this.gridMargin = 16,
    this.rowUnit = 48,
    this.cmdbarHeight = 48,
    this.toolbarHeight = 32,
    this.railWidth = 72,
    this.drawerWidth = 256,
    this.sheetWidth = 400,
    this.dialogWidth = 520,
    this.bpMedium = 600,
    this.bpExpanded = 840,
    this.bpLarge = 1200,
    this.bpXlarge = 1600,
    this.bpWall = 2560,
  });

  /// Glyph to word, segment gaps, fine alignment.
  final double space1;

  /// Gutter between tiled panels, tag side padding.
  final double space2;

  /// Panel header side padding, row padding.
  final double space3;

  /// Panel body padding, gap between components.
  final double space4;

  /// Section gap.
  final double space6;

  /// Screen edge margin.
  final double space8;

  /// CommandBar height, large block unit.
  final double space12;

  /// Panel borders, dividers, grid lines.
  final double stroke1;

  /// Corner brackets, active borders, focus ring.
  final double stroke2;

  /// CommandBar bottom line, alarm edges.
  final double stroke4;

  /// Tags and small code blocks.
  final double chamferSm;

  /// Buttons (top left and bottom right).
  final double chamferMd;

  /// Panel header code block slant, large plates.
  final double chamferLg;

  /// Fine grid inside traces and plots.
  final double pitchFine;

  /// Screen background grid.
  final double pitchGrid;

  /// Width of one hazard stripe (the period is twice this).
  final double pitchHazard;

  /// HexMatrix cell width (height = width × 1.155).
  final double pitchHex;

  /// Gutter between panels. Fixed at every window size.
  final double gridGutter;

  /// Screen edge margin at expanded and above. Compact is 8, wall is 32.
  final double gridMargin;

  /// Panel height unit. A cell with `rows = n` is n×rowUnit + (n−1)×gutter tall.
  final double rowUnit;

  final double cmdbarHeight;
  final double toolbarHeight;
  final double railWidth;
  final double drawerWidth;
  final double sheetWidth;
  final double dialogWidth;

  final double bpMedium;
  final double bpExpanded;
  final double bpLarge;
  final double bpXlarge;
  final double bpWall;

  /// The window size class for [width].
  KkWindowClass windowClass(double width) {
    if (width >= bpWall) return KkWindowClass.wall;
    if (width >= bpXlarge) return KkWindowClass.xlarge;
    if (width >= bpLarge) return KkWindowClass.large;
    if (width >= bpExpanded) return KkWindowClass.expanded;
    if (width >= bpMedium) return KkWindowClass.medium;
    return KkWindowClass.compact;
  }

  /// Grid column count for a container [width]: 4 / 8 / 12 / 16 / 24.
  int columnsFor(double width) {
    if (width >= bpWall) return 24;
    if (width >= bpXlarge) return 16;
    if (width >= bpExpanded) return 12;
    if (width >= bpMedium) return 8;
    return 4;
  }

  /// Screen edge margin for a window [width]: 8 compact, 32 wall, else [gridMargin].
  double marginFor(double width) {
    if (width >= bpWall) return space8;
    if (width < bpMedium) return space2;
    return gridMargin;
  }

  /// Height of a grid cell that spans [rows] row units.
  double rowsHeight(int rows) => rows * rowUnit + (rows - 1) * gridGutter;

  KkMetrics copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space6,
    double? space8,
    double? space12,
    double? stroke1,
    double? stroke2,
    double? stroke4,
    double? chamferSm,
    double? chamferMd,
    double? chamferLg,
    double? pitchFine,
    double? pitchGrid,
    double? pitchHazard,
    double? pitchHex,
    double? gridGutter,
    double? gridMargin,
    double? rowUnit,
    double? cmdbarHeight,
    double? toolbarHeight,
    double? railWidth,
    double? drawerWidth,
    double? sheetWidth,
    double? dialogWidth,
    double? bpMedium,
    double? bpExpanded,
    double? bpLarge,
    double? bpXlarge,
    double? bpWall,
  }) {
    return KkMetrics(
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
      space12: space12 ?? this.space12,
      stroke1: stroke1 ?? this.stroke1,
      stroke2: stroke2 ?? this.stroke2,
      stroke4: stroke4 ?? this.stroke4,
      chamferSm: chamferSm ?? this.chamferSm,
      chamferMd: chamferMd ?? this.chamferMd,
      chamferLg: chamferLg ?? this.chamferLg,
      pitchFine: pitchFine ?? this.pitchFine,
      pitchGrid: pitchGrid ?? this.pitchGrid,
      pitchHazard: pitchHazard ?? this.pitchHazard,
      pitchHex: pitchHex ?? this.pitchHex,
      gridGutter: gridGutter ?? this.gridGutter,
      gridMargin: gridMargin ?? this.gridMargin,
      rowUnit: rowUnit ?? this.rowUnit,
      cmdbarHeight: cmdbarHeight ?? this.cmdbarHeight,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      railWidth: railWidth ?? this.railWidth,
      drawerWidth: drawerWidth ?? this.drawerWidth,
      sheetWidth: sheetWidth ?? this.sheetWidth,
      dialogWidth: dialogWidth ?? this.dialogWidth,
      bpMedium: bpMedium ?? this.bpMedium,
      bpExpanded: bpExpanded ?? this.bpExpanded,
      bpLarge: bpLarge ?? this.bpLarge,
      bpXlarge: bpXlarge ?? this.bpXlarge,
      bpWall: bpWall ?? this.bpWall,
    );
  }

  List<double> get _props => <double>[
    space1, space2, space3, space4, space6, space8, space12, //
    stroke1, stroke2, stroke4, chamferSm, chamferMd, chamferLg, //
    pitchFine, pitchGrid, pitchHazard, pitchHex, gridGutter, gridMargin, rowUnit, //
    cmdbarHeight, toolbarHeight, railWidth, drawerWidth, sheetWidth, dialogWidth, //
    bpMedium, bpExpanded, bpLarge, bpXlarge, bpWall,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KkMetrics && listEquals(other._props, _props));

  @override
  int get hashCode => Object.hashAll(_props);
}

/// Stacking order. Alarms are always on top.
abstract final class KkLayer {
  static const int base = 0;
  static const int sticky = 10;
  static const int overlay = 100;
  static const int sheet = 200;
  static const int modal = 300;
  static const int toast = 400;
  static const int alert = 500;
}
