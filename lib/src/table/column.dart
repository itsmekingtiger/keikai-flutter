import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum _WidthKind { fixed, content, flex }

/// How wide a column of a [KkDataTable] is.
///
/// * [KkTableWidth.fixed]: exactly that many pixels.
/// * [KkTableWidth.content] (the default): as wide as its header and its
///   widest cell, like a column of an HTML table. When the table has no flex
///   column, content columns share the width that is left over in proportion
///   to their content.
/// * [KkTableWidth.flex]: a share of the width the other columns leave.
///
/// When the columns need more width than the table has, they keep their
/// widths and the table scrolls sideways.
@immutable
class KkTableWidth {
  /// Exactly [width] px.
  const KkTableWidth.fixed(double width) : _kind = _WidthKind.fixed, min = width, max = width, flex = 0;

  /// As wide as the header and the widest cell laid out so far, but never
  /// narrower than [min] or wider than [max].
  ///
  /// Cells are measured as their rows are built, so a long table that scrolls
  /// in a wider cell widens the column once; the width never shrinks again
  /// while the columns stay the same. Cells of a content column are asked for
  /// their intrinsic width: give the column a fixed or flex width if a cell
  /// cannot answer (a `LayoutBuilder`, a nested scroll view).
  const KkTableWidth.content({this.min = 0, this.max = double.infinity}) : _kind = _WidthKind.content, flex = 0;

  /// [flex] shares of the width the fixed and content columns leave, never
  /// narrower than [min] or than the header, never wider than [max].
  const KkTableWidth.flex({this.flex = 1, this.min = 64, this.max = double.infinity})
    : _kind = _WidthKind.flex,
      assert(flex > 0);

  final _WidthKind _kind;

  /// The smallest width (the width itself for a fixed column).
  final double min;

  /// The largest width (the width itself for a fixed column).
  final double max;

  /// The share of the spare width a flex column takes; 0 for the other kinds.
  final double flex;

  bool get isFixed => _kind == _WidthKind.fixed;
  bool get isContent => _kind == _WidthKind.content;
  bool get isFlex => _kind == _WidthKind.flex;

  @override
  bool operator ==(Object other) =>
      other is KkTableWidth && other._kind == _kind && other.min == min && other.max == max && other.flex == flex;

  @override
  int get hashCode => Object.hash(_kind, min, max, flex);

  @override
  String toString() => switch (_kind) {
    _WidthKind.fixed => 'KkTableWidth.fixed($min)',
    _WidthKind.content => 'KkTableWidth.content(min: $min, max: $max)',
    _WidthKind.flex => 'KkTableWidth.flex($flex, min: $min, max: $max)',
  };
}

/// Where a cell's content sits in its column.
enum KkTableAlign { start, center, end }

/// The direction of a sort.
enum KkSortDirection { ascending, descending }

/// Which column a [KkDataTable] is sorted by, and in which direction.
@immutable
class KkTableSort {
  const KkTableSort(this.column, [this.direction = KkSortDirection.ascending]);

  /// "Not sorted", said by an owner who controls the sort: a table given
  /// `sort: KkTableSort.none` stays unsorted until its owner says otherwise,
  /// where `sort: null` would let the table keep a sort of its own.
  static const KkTableSort none = KkTableSort('');

  /// The [KkTableColumn.id] of the sorted column.
  final String column;
  final KkSortDirection direction;

  bool get ascending => direction == KkSortDirection.ascending;

  /// Whether this is [none].
  bool get isNone => column.isEmpty;

  @override
  bool operator ==(Object other) => other is KkTableSort && other.column == column && other.direction == direction;

  @override
  int get hashCode => Object.hash(column, direction);

  @override
  String toString() => 'KkTableSort($column, ${direction.name})';
}

/// How rows of a [KkDataTable] can be selected.
enum KkTableSelection {
  /// Rows cannot be selected.
  none,

  /// One row at a time. Pressing a row selects it.
  single,

  /// Any number of rows, with a checkbox column and a tri-state checkbox in
  /// the header.
  multi,
}

/// One cell of a [KkDataTable]: a row (by its key) and a column (by its id).
@immutable
class KkTableCellRef {
  const KkTableCellRef(this.rowKey, this.column);

  final Object rowKey;
  final String column;

  @override
  bool operator ==(Object other) => other is KkTableCellRef && other.rowKey == rowKey && other.column == column;

  @override
  int get hashCode => Object.hash(rowKey, column);

  @override
  String toString() => 'KkTableCellRef($rowKey, $column)';
}

/// A column of a [KkDataTable].
///
/// The simplest column gives a [value]; the cell then shows it as mono text
/// (through [format] when given), the column can be sorted and filtered by it,
/// and a change of the value flashes the cell. A [cell] builder replaces the
/// text with any widget: the ready-made cell kinds are `KkTableLevel`,
/// `KkTableCode`, `KkTableValue`, `KkTableBar`, `KkTableMeter` and
/// `KkTableSpark`.
///
/// ```dart
/// KkTableColumn<Pump>(
///   id: 'flow',
///   cjk: '流量',
///   en: 'flow',
///   unit: 'L/min',
///   numeric: true,
///   sortable: true,
///   value: (Pump p) => p.flow,
///   format: (Pump p) => kkFixed(p.flow, digits: 3),
/// )
/// ```
@immutable
class KkTableColumn<T> {
  const KkTableColumn({
    required this.id,
    this.cjk,
    this.en,
    this.unit,
    this.numeric = false,
    this.width = const KkTableWidth.content(),
    this.align,
    this.value,
    this.format,
    this.cell,
    this.sortable = false,
    this.compare,
    this.truncate = false,
    this.tooltip,
    this.searchable = true,
    this.editable = false,
    this.canEdit,
    this.editText,
    this.onEdited,
    this.validator,
    this.editFormatters,
    this.editKeyboardType,
    this.editMaxLength,
    this.commitOnBlur = false,
    this.summary,
    this.semanticLabel,
  });

  /// Names the column in [KkTableSort], in [KkTableCellRef] and in change
  /// detection. Unique within a table.
  final String id;

  /// The CJK header word. When any column has one, every header is two lines
  /// high.
  final String? cjk;

  /// The Latin header label; shown in capitals.
  final String? en;

  /// A unit after [en], kept in its own case (`°C`, `L/min`).
  final String? unit;

  /// Right-align the header and the cells.
  final bool numeric;
  final KkTableWidth width;

  /// Overrides the alignment ([numeric] gives end, otherwise start).
  final KkTableAlign? align;

  /// The value of a row in this column: what the cell shows (unless [cell] is
  /// given), what the column sorts and filters by, and what is compared from
  /// one build to the next to flash a changed cell.
  final Object? Function(T row)? value;

  /// The text of a cell. Defaults to [value] as a string, `--` for null.
  final String Function(T row)? format;

  /// Builds the cell. Replaces the text of [value] / [format].
  final Widget Function(BuildContext context, T row)? cell;

  /// Let the header sort by this column. Needs [compare] or [value].
  final bool sortable;

  /// Orders two rows ascending. Defaults to comparing [value]s: numbers by
  /// size, other `Comparable`s by `compareTo`, anything else as text. Rows
  /// whose value is null (or NaN) come last in both directions.
  final int Function(T a, T b)? compare;

  /// Cut text that does not fit with an ellipsis instead of clipping it.
  final bool truncate;

  /// A note shown when the pointer rests on the header.
  final String? tooltip;

  /// Whether the table's filter field looks at this column's text.
  final bool searchable;

  /// Let cells of this column be edited in place. Needs [onEdited].
  final bool editable;

  /// Whether the cell of [row] can be edited. Defaults to every row.
  final bool Function(T row)? canEdit;

  /// The text the editor starts with. Defaults to the cell's text.
  final String Function(T row)? editText;

  /// Called with the new text when an edit is committed (Enter).
  final void Function(T row, String text)? onEdited;

  /// Returns a message when [text] cannot be accepted; the editor then stays
  /// open in its error state.
  final String? Function(T row, String text)? validator;
  final List<TextInputFormatter>? editFormatters;
  final TextInputType? editKeyboardType;
  final int? editMaxLength;

  /// What losing the focus does to an open editor: commit the text when true,
  /// drop it when false (the default: a value changes only on Enter).
  final bool commitOnBlur;

  /// Builds this column's cell of the summary row from the rows that pass the
  /// filter. The table shows a summary row when any column has one.
  final Widget Function(BuildContext context, List<T> rows)? summary;

  /// What screen readers call the column. Defaults to [en], then [cjk].
  final String? semanticLabel;

  /// The alignment of header and cells.
  KkTableAlign get alignment => align ?? (numeric ? KkTableAlign.end : KkTableAlign.start);

  /// Whether the cells of [row] can be edited.
  bool editableFor(T row) => editable && onEdited != null && (canEdit?.call(row) ?? true);

  /// The name of the column for screen readers.
  String get label => semanticLabel ?? en ?? cjk ?? id;

  /// The text of [row]'s cell.
  String textOf(T row) {
    final String Function(T row)? f = format;
    if (f != null) return f(row);
    final Object? v = value?.call(row);
    if (v == null) return '--';
    if (v is double && !v.isFinite) return '--';
    return v.toString();
  }

  /// Orders [a] and [b] ascending by this column.
  int compareRows(T a, T b) {
    final int Function(T a, T b)? c = compare;
    if (c != null) return c(a, b);
    final Object? Function(T row)? v = value;
    if (v == null) return 0;
    return kkCompareTableValues(v(a), v(b));
  }

  /// Whether [row] has no value to sort by in this column (null or NaN).
  bool isBlank(T row) {
    final Object? Function(T row)? v = value;
    if (v == null) return false;
    final Object? x = v(row);
    return x == null || (x is double && x.isNaN);
  }
}

/// Orders two cell values ascending: numbers by size, other [Comparable]s of
/// the same kind by `compareTo`, anything else by its text. Null and NaN are
/// treated as equal to each other here; [KkDataTable] sorts them last.
int kkCompareTableValues(Object? a, Object? b) {
  final bool blankA = a == null || (a is double && a.isNaN);
  final bool blankB = b == null || (b is double && b.isNaN);
  if (blankA || blankB) return blankA == blankB ? 0 : (blankA ? 1 : -1);
  if (a is num && b is num) return a.compareTo(b);
  if (a is String && b is String) return a.compareTo(b);
  if (a is DateTime && b is DateTime) return a.compareTo(b);
  if (a is Duration && b is Duration) return a.compareTo(b);
  if (a is bool && b is bool) return a == b ? 0 : (a ? 1 : -1);
  if (a is Enum && b is Enum) return a.index.compareTo(b.index);
  if (a is Comparable<Object?> && a.runtimeType == b.runtimeType) {
    try {
      return a.compareTo(b);
    } on Object {
      // Falls through to the text comparison.
    }
  }
  return a.toString().compareTo(b.toString());
}
