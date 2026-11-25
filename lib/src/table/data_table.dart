import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/checkbox.dart';
import '../controls/icon_button.dart';
import '../controls/scan.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../inputs/modality.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../layout/scroll.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'band.dart';
import 'cells.dart';
import 'column.dart';
import 'edit.dart';
import 'frame.dart';
import 'header.dart';
import 'layout.dart';
import 'pagination.dart';
import 'rows.dart';

/// The flicker a body row enters with: the panel flicker in six steps.
const KkKeyframes _rowFlicker = KkKeyframes(
  <double>[0, 0.2, 0.3, 0.45, 0.55, 0.7, 1],
  <double>[0, 0.9, 0.1, 1, 0.35, 1, 1],
  steps: 6,
);

const Duration _rowFlickerTime = Duration(milliseconds: 400);
const Duration _cellFlashTime = Duration(milliseconds: 900);
const Duration _rowShiftTime = Duration(milliseconds: 1200);

/// Rows beyond this one enter together with it; without the cap the last row
/// of a long page would wait for seconds.
const int _entranceRows = 24;

enum _ColKind { check, number, expander, data }

class _Col<T> {
  const _Col.special(this.kind, this.width) : column = null;
  _Col.data(KkTableColumn<T> this.column) : kind = _ColKind.data, width = column.width;

  final _ColKind kind;
  final KkTableWidth width;
  final KkTableColumn<T>? column;
}

/// What the table shows right now: the rows that pass the filter, in sort
/// order, and the page of them that is on screen.
class _View<T> {
  _View({
    required this.filtered,
    required this.rows,
    required this.keys,
    required this.indexOf,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.first,
    required this.noMatch,
  });

  /// Every row that passes the filter, sorted.
  final List<T> filtered;

  /// The rows of the current page.
  final List<T> rows;
  final List<Object> keys;
  final Map<Object, int> indexOf;

  /// How many rows there are on all pages.
  final int total;
  final int page;
  final int pageCount;

  /// The number (from 0) of the first row of the page among all rows.
  final int first;

  /// There are rows, but the filter leaves none.
  final bool noMatch;
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// The scroll physics of the rows: no bounce, and no gliding back either.
/// When the rows get shorter than the scroll offset (a filter, a closed
/// detail, another page size) the offset is put back in range at once, where
/// the framework's own physics would let it drift back on a spring.
class _RowPhysics extends ClampingScrollPhysics {
  const _RowPhysics({super.parent});

  @override
  _RowPhysics applyTo(ScrollPhysics? ancestor) => _RowPhysics(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final double pixels = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    return pixels.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent);
  }
}

/// A data table in the KEIKAI grammar.
///
/// Rows are any objects; [rowKey] tells them apart and [columns] say what to
/// show of them. Everything else is optional and switches on by being given:
///
/// * a toolbar band ([code], [cjk], [en], [meta], [filterable], [actions]);
/// * sorting (a column with `sortable: true`), by pressing a header: none,
///   ascending, descending, none again;
/// * selection ([selection]): one row at a time, or many with a checkbox
///   column, a tri-state checkbox in the header for the rows of the page,
///   Shift for a range, and a signal band with [bulkActions] while rows are
///   selected;
/// * detail rows ([detail]), row numbers ([showRowNumbers]), a level and a
///   progress fill per row ([rowLevel], [rowFill]);
/// * a summary row (a column with a `summary`), paging ([pageSize] or
///   [initialPageSize]) with a footer, a loading rail and skeleton rows
///   ([loading]), and an empty state.
///
/// Sort, filter, selection, expanded rows, page and page size each work on
/// their own (the table keeps the state) or are controlled by passing the
/// value: a non-null [sort], [filter], [selected], [expanded], [page] or
/// [pageSize] is shown as given and changes only when the owner rebuilds with
/// a new one. The `on…Changed` callbacks are called either way.
///
/// With [totalRows] the table shows one page of a larger, remote set: [rows]
/// are the rows of the current page, and sorting, filtering and paging are
/// only reported, not applied.
///
/// The body scrolls when the table is given a height and builds rows only as
/// they come into view; without a height limit the table is as high as its
/// rows. When the columns need more width than there is, header, rows and
/// summary scroll sideways together.
///
/// Keyboard: the rows are one tab stop. Up, Down, Home, End, Page Up and Page
/// Down move the focused row; Enter activates it ([onRowPressed], or opens
/// and closes its detail); Space selects it (Shift+Space a range, Ctrl+A the
/// page); Right and Left open and close its detail.
///
/// ```dart
/// KkDataTable<Pump>(
///   code: 'TBL-01',
///   cjk: '機器',
///   en: 'pumps',
///   rows: pumps,
///   rowKey: (Pump p) => p.id,
///   rowLevel: (Pump p) => p.level,
///   selection: KkTableSelection.multi,
///   columns: <KkTableColumn<Pump>>[
///     KkTableColumn<Pump>(id: 'id', en: 'id', cell: (_, Pump p) => KkTableCode(p.id)),
///     KkTableColumn<Pump>(id: 'flow', en: 'flow', unit: 'L/min', numeric: true, sortable: true,
///         value: (Pump p) => p.flow, format: (Pump p) => kkFixed(p.flow, digits: 3)),
///     KkTableColumn<Pump>(id: 'state', en: 'state', cell: (_, Pump p) => KkTableLevel(level: p.level)),
///   ],
/// )
/// ```
class KkDataTable<T> extends StatefulWidget {
  const KkDataTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.rowKey,
    this.code,
    this.cjk,
    this.en,
    this.meta,
    this.actions = const <Widget>[],
    this.showBand,
    this.filterable = false,
    this.filter,
    this.onFilterChanged,
    this.filterPlaceholder = 'filter',
    this.filterPredicate,
    this.sort,
    this.initialSort,
    this.onSortChanged,
    this.selection = KkTableSelection.none,
    this.selected,
    this.onSelectionChanged,
    this.showCheckboxes,
    this.bulkActions = const <KkTableBulkAction>[],
    this.selectionCjk = '選択',
    this.selectionEn = 'selected',
    this.dense = false,
    this.rowHeight,
    this.rowLevel,
    this.rowFill,
    this.onRowPressed,
    this.showRowNumbers = false,
    this.rowNumberLabel = 'No',
    this.rowSemanticLabel,
    this.detail,
    this.canExpand,
    this.expanded,
    this.onExpandedChanged,
    this.pageSize,
    this.initialPageSize,
    this.pageSizeOptions = const <int>[],
    this.page,
    this.onPageChanged,
    this.onPageSizeChanged,
    this.totalRows,
    this.showFooter,
    this.loading = false,
    this.skeletonRows = 6,
    this.emptyCjk = '無記録',
    this.emptyEn = 'no records',
    this.noMatchCjk = '該当無',
    this.noMatchEn = 'no match',
    this.emptyBuilder,
    this.frame = true,
    this.boot = true,
    this.entrance = true,
    this.flashChanges = true,
    this.squeeze = 0.8,
    this.fill,
    this.initiallyEditing,
    this.focusNode,
    this.autofocus = false,
    this.scrollController,
    this.horizontalController,
    this.semanticLabel,
  }) : assert(rowHeight == null || rowHeight > 0),
       assert(pageSize == null || pageSize > 0),
       assert(initialPageSize == null || initialPageSize > 0),
       assert(skeletonRows >= 0);

  /// The data. With [totalRows] these are the rows of the current page only.
  final List<T> rows;
  final List<KkTableColumn<T>> columns;

  /// What tells one row from another: an id, never the position. Selection,
  /// expanded rows, change flashes and row state all go by it.
  final Object Function(T row) rowKey;

  /// The identifier in the band's code block, such as `TBL-01`.
  final String? code;

  /// The CJK title in the band.
  final String? cjk;

  /// The Latin title in the band; shown in capitals.
  final String? en;

  /// Short mono text in the band (a count, a time).
  final String? meta;

  /// Widgets at the right of the band: small buttons, a time range.
  final List<Widget> actions;

  /// Whether the band is shown. By default it is whenever it has something to
  /// show or rows can be selected.
  final bool? showBand;

  /// Put a filter field in the band.
  final bool filterable;

  /// The filter text, when the owner controls it.
  final String? filter;
  final ValueChanged<String>? onFilterChanged;
  final String filterPlaceholder;

  /// Decides whether [row] passes [query] (already trimmed and lower-cased).
  /// By default a row passes when the text of any searchable column contains
  /// the query.
  final bool Function(T row, String query)? filterPredicate;

  /// The sort, when the owner controls it. Pass [KkTableSort.none] for
  /// "controlled, not sorted"; null leaves the sort to the table.
  final KkTableSort? sort;

  /// The sort a table that keeps its own sort starts with.
  final KkTableSort? initialSort;

  /// Called with the new sort, null for none.
  final ValueChanged<KkTableSort?>? onSortChanged;
  final KkTableSelection selection;

  /// The keys of the selected rows, when the owner controls the selection.
  /// Keys of rows that are gone are ignored.
  final Set<Object>? selected;
  final ValueChanged<Set<Object>>? onSelectionChanged;

  /// Show the checkbox column. Defaults to true for [KkTableSelection.multi].
  final bool? showCheckboxes;

  /// Actions on the selected rows, shown in the band while rows are selected.
  final List<KkTableBulkAction> bulkActions;

  /// The label beside the count in the selection band.
  final String selectionCjk;
  final String selectionEn;

  /// 24px rows and 11px type instead of 32px and 12px.
  final bool dense;

  /// Overrides the row height (32, or 24 when [dense]).
  final double? rowHeight;

  /// The level of a row. Critical rows are drawn on the alarm ground; a row
  /// whose level changes strobes three times.
  final KkLevel? Function(T row)? rowLevel;

  /// Progress of a row, 0 to 1, drawn as a fill across the row.
  final double? Function(T row)? rowFill;

  /// Called when a row is pressed, or Enter is pressed on the focused row.
  final ValueChanged<T>? onRowPressed;

  /// Show a row number column.
  final bool showRowNumbers;

  /// The header of the row number column.
  final String rowNumberLabel;

  /// What screen readers say for a row before its cells.
  final String Function(T row)? rowSemanticLabel;

  /// Builds the detail block of a row. Giving one adds the expander column.
  final Widget Function(BuildContext context, T row)? detail;

  /// Whether [row] has a detail block. Defaults to every row.
  final bool Function(T row)? canExpand;

  /// The keys of the expanded rows, when the owner controls them.
  final Set<Object>? expanded;
  final ValueChanged<Set<Object>>? onExpandedChanged;

  /// Rows per page, when the owner controls it. Giving it turns paging on.
  final int? pageSize;

  /// Rows per page for a table that keeps its own page size. Giving it turns
  /// paging on. A later change of this value sets the page size again and
  /// goes back to the first page.
  final int? initialPageSize;

  /// The choices of the rows-per-page select in the footer. The select is
  /// shown when there are at least two.
  final List<int> pageSizeOptions;

  /// The page (from 0), when the owner controls it. A page beyond the last is
  /// shown as the last.
  final int? page;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  /// The number of rows on all pages of a remote set. Giving it stops the
  /// table from sorting, filtering and slicing [rows] itself.
  final int? totalRows;

  /// Whether the footer is shown. By default it is when the table is paged.
  final bool? showFooter;

  /// Scan the loading rail, and show skeleton rows while there are no rows.
  final bool loading;

  /// How many skeleton rows a loading, empty table shows.
  final int skeletonRows;

  /// What a table without rows says.
  final String emptyCjk;
  final String emptyEn;

  /// What a table says when the filter leaves no row.
  final String noMatchCjk;
  final String noMatchEn;

  /// Replaces the empty block. [noMatch] tells a filter that matched nothing
  /// from a table without data.
  final Widget Function(BuildContext context, bool noMatch)? emptyBuilder;

  /// Draw the 1px frame. Turn it off inside a flush panel body.
  final bool frame;

  /// Play the boot wipe when first shown.
  final bool boot;

  /// Let rows flicker in when the table appears and when its rows are
  /// replaced (sort, filter, page).
  final bool entrance;

  /// Flash a cell whose value changed and strobe a row whose level changed.
  final bool flashChanges;

  /// Horizontal compression of the CJK words in band and header.
  final double squeeze;

  /// Overrides the ground (bg-100).
  final Color? fill;

  /// A cell that starts with its editor open, without the focus (for
  /// catalogues and tests).
  final KkTableCellRef? initiallyEditing;

  /// The focus node of the rows.
  final FocusNode? focusNode;
  final bool autofocus;

  /// The vertical scroll controller of the rows.
  final ScrollController? scrollController;

  /// The scroll controller of the sideways scroll.
  final ScrollController? horizontalController;

  /// What screen readers call the table. Defaults to the title.
  final String? semanticLabel;

  @override
  State<KkDataTable<T>> createState() => _KkDataTableState<T>();
}

class _KkDataTableState<T> extends State<KkDataTable<T>> {
  final KkTableLink _link = KkTableLink();
  final KkTableRowPaint _headerLook = KkTableRowPaint();
  final KkTableRowPaint _summaryLook = KkTableRowPaint();
  final _Signal _disarm = _Signal();
  final TextEditingController _filterController = TextEditingController();

  ScrollController? _ownVertical;
  ScrollController? _ownHorizontal;
  FocusNode? _ownFocus;

  ScrollController get _vertical => widget.scrollController ?? (_ownVertical ??= ScrollController());
  ScrollController get _horizontal => widget.horizontalController ?? (_ownHorizontal ??= ScrollController());
  FocusNode get _bodyFocus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KkDataTable'));

  // State the table keeps when its owner does not.
  KkTableSort? _sort;
  Set<Object> _selected = <Object>{};
  Set<Object> _expanded = <Object>{};
  int _page = 0;
  int? _pageSize;

  Object? _focusedKey;
  Object? _anchorKey;
  bool _showFocus = false;

  _View<T>? _view;
  Set<Object>? _allKeys;
  int _rowsVersion = 0;

  // Change feedback.
  List<String> _trackedIds = const <String>[];
  Map<Object, List<Object?>> _values = <Object, List<Object?>>{};
  Map<Object, KkLevel?> _levels = <Object, KkLevel?>{};
  final Map<Object, List<int>> _flashes = <Object, List<int>>{};
  final Map<Object, int> _shifts = <Object, int>{};

  // Entrance.
  int _generation = 0;
  bool _entranceOpen = false;

  final Map<Object, _KkTableRowState<T>> _mounted = <Object, _KkTableRowState<T>>{};

  bool get _server => widget.totalRows != null;

  @override
  void initState() {
    super.initState();
    KkInputModality.watch();
    _sort = widget.initialSort;
    _pageSize = widget.initialPageSize;
    _filterController.text = widget.filter ?? '';
    _bodyFocus.addListener(_onFocusChanged);
    _track(first: true);
    _openEntrance();
  }

  @override
  void didUpdateWidget(KkDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChanged);
      _bodyFocus.addListener(_onFocusChanged);
    }
    final String? filter = widget.filter;
    if (filter != null && filter != _filterController.text) {
      _filterController.value = TextEditingValue(
        text: filter,
        selection: TextSelection.collapsed(offset: filter.length),
      );
    }
    if (oldWidget.initialPageSize != widget.initialPageSize) {
      // Paging was switched on or off, or set to another size, from outside.
      _pageSize = widget.initialPageSize;
      _page = 0;
    }
    // The owner may have changed the data, or what is shown of it.
    final bool reshuffled =
        oldWidget.sort != widget.sort ||
        oldWidget.filter != widget.filter ||
        oldWidget.page != widget.page ||
        oldWidget.pageSize != widget.pageSize ||
        oldWidget.initialPageSize != widget.initialPageSize;
    _view = null;
    _allKeys = null;
    _track(first: false);
    if (reshuffled) _bumpGeneration();
    if (widget.selected == null && _selected.isNotEmpty && !_server) {
      // A table that keeps its own selection forgets rows that are gone.
      final Set<Object> all = _keysOfAllRows();
      if (!all.containsAll(_selected)) _selected = _selected.intersection(all);
    }
  }

  @override
  void dispose() {
    _bodyFocus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    _ownVertical?.dispose();
    _ownHorizontal?.dispose();
    _filterController.dispose();
    _headerLook.dispose();
    _summaryLook.dispose();
    _skeletonPaint.dispose();
    _disarm.dispose();
    super.dispose();
  }

  // ── what is shown ────────────────────────────────────────────────────────

  KkTableSort? get _sortNow {
    final KkTableSort? given = widget.sort;
    if (given != null) return given.isNone ? null : given;
    return _sort;
  }

  String get _filterNow => (widget.filter ?? _filterController.text).trim().toLowerCase();
  int? get _sizeNow => widget.pageSize ?? _pageSize;
  int get _pageNow => widget.page ?? _page;
  Set<Object> get _selectedNow => widget.selected ?? _selected;
  Set<Object> get _expandedNow => widget.expanded ?? _expanded;

  KkTableColumn<T>? _columnById(String id) {
    for (final KkTableColumn<T> c in widget.columns) {
      if (c.id == id) return c;
    }
    return null;
  }

  Set<Object> _keysOfAllRows() => _allKeys ??= <Object>{for (final T row in widget.rows) widget.rowKey(row)};

  /// The selected rows that exist. A remote set cannot be checked.
  Set<Object> get _selectedExisting {
    final Set<Object> now = _selectedNow;
    if (now.isEmpty || _server) return now;
    final Set<Object> all = _keysOfAllRows();
    return all.containsAll(now) ? now : now.intersection(all);
  }

  bool _matches(T row, String query) {
    final bool Function(T row, String query)? custom = widget.filterPredicate;
    if (custom != null) return custom(row, query);
    for (final KkTableColumn<T> c in widget.columns) {
      if (!c.searchable || (c.value == null && c.format == null)) continue;
      if (c.textOf(row).toLowerCase().contains(query)) return true;
    }
    return false;
  }

  _View<T> get _viewNow => _view ??= _computeView();

  _View<T> _computeView() {
    final List<T> all = widget.rows;
    List<T> filtered = all;
    if (!_server) {
      final String query = _filterNow;
      if (query.isNotEmpty) {
        filtered = <T>[
          for (final T row in all)
            if (_matches(row, query)) row,
        ];
      }
      final KkTableSort? sort = _sortNow;
      final KkTableColumn<T>? by = sort == null ? null : _columnById(sort.column);
      if (sort != null && by != null && by.sortable && (by.compare != null || by.value != null)) {
        // A stable sort: rows that compare equal keep the order they came
        // in, and rows without a value go last whichever way the sort runs.
        final List<int> order = List<int>.generate(filtered.length, (int i) => i);
        final List<T> source = filtered;
        final int sign = sort.ascending ? 1 : -1;
        order.sort((int a, int b) {
          final bool blankA = by.isBlank(source[a]);
          final bool blankB = by.isBlank(source[b]);
          if (blankA != blankB) return blankA ? 1 : -1;
          final int c = blankA ? 0 : by.compareRows(source[a], source[b]) * sign;
          return c != 0 ? c : a - b;
        });
        filtered = <T>[for (final int i in order) source[i]];
      }
    }
    final int total = widget.totalRows ?? filtered.length;
    final int? size = _sizeNow;
    final int pageCount = size == null ? 1 : math.max(1, (total / size).ceil());
    final int page = size == null ? 0 : _pageNow.clamp(0, pageCount - 1);
    final int first = size == null ? 0 : page * size;
    final List<T> rows = (size == null || _server)
        ? filtered
        : filtered.sublist(math.min(first, filtered.length), math.min(first + size, filtered.length));
    final List<Object> keys = <Object>[for (final T row in rows) widget.rowKey(row)];
    final Map<Object, int> indexOf = <Object, int>{};
    for (int i = 0; i < keys.length; i++) {
      indexOf[keys[i]] = i;
    }
    assert(indexOf.length == keys.length, 'KkDataTable: rowKey gave the same key to two rows.');
    return _View<T>(
      filtered: filtered,
      rows: rows,
      keys: keys,
      indexOf: indexOf,
      total: total,
      page: page,
      pageCount: pageCount,
      first: first,
      noMatch: !_server && all.isNotEmpty && filtered.isEmpty,
    );
  }

  void _reshuffle(VoidCallback change) {
    setState(() {
      change();
      _view = null;
      _bumpGeneration();
    });
    if (_vertical.hasClients && _vertical.offset != 0) _vertical.jumpTo(0);
  }

  // ── entrance and change feedback ─────────────────────────────────────────

  void _openEntrance() {
    _entranceOpen = true;
    // Rows that are built later (scrolled into view) do not flicker.
    SchedulerBinding.instance.addPostFrameCallback((Duration _) => _entranceOpen = false);
  }

  void _bumpGeneration() {
    _generation++;
    _openEntrance();
  }

  /// Compares every row with what it held at the last build. A cell whose
  /// value changed gets a higher flash count, a row whose level changed a
  /// higher shift count; mounted rows play the effect when their count moves.
  void _track({required bool first}) {
    if (!widget.flashChanges) {
      _values = <Object, List<Object?>>{};
      _levels = <Object, KkLevel?>{};
      _flashes.clear();
      _shifts.clear();
      _trackedIds = const <String>[];
      return;
    }
    final List<KkTableColumn<T>> tracked = <KkTableColumn<T>>[
      for (final KkTableColumn<T> c in widget.columns)
        if (c.value != null) c,
    ];
    final List<String> ids = <String>[for (final KkTableColumn<T> c in tracked) c.id];
    bool sameColumns = ids.length == _trackedIds.length;
    for (int i = 0; sameColumns && i < ids.length; i++) {
      sameColumns = ids[i] == _trackedIds[i];
    }
    final bool compare = !first && sameColumns;
    final KkLevel? Function(T row)? levelOf = widget.rowLevel;
    final Map<Object, List<Object?>> values = <Object, List<Object?>>{};
    final Map<Object, KkLevel?> levels = <Object, KkLevel?>{};
    for (final T row in widget.rows) {
      final Object key = widget.rowKey(row);
      final List<Object?> now = <Object?>[for (final KkTableColumn<T> c in tracked) c.value!(row)];
      values[key] = now;
      final KkLevel? level = levelOf?.call(row);
      levels[key] = level;
      if (!compare) continue;
      final List<Object?>? before = _values[key];
      if (before == null) continue;
      List<int>? counts;
      for (int i = 0; i < now.length; i++) {
        if (!_same(before[i], now[i])) {
          // A new list each time: a mounted row tells a change by comparing
          // the list it had with the list it gets.
          counts ??= List<int>.of(_flashes[key] ?? List<int>.filled(now.length, 0));
          counts[i]++;
        }
      }
      if (counts != null) _flashes[key] = counts;
      if (_levels.containsKey(key) && _levels[key] != level) {
        _shifts[key] = (_shifts[key] ?? 0) + 1;
      }
    }
    if (!sameColumns) _flashes.clear();
    _flashes.removeWhere((Object key, List<int> _) => !values.containsKey(key));
    _shifts.removeWhere((Object key, int _) => !values.containsKey(key));
    _values = values;
    _levels = levels;
    _trackedIds = ids;
  }

  static bool _same(Object? a, Object? b) {
    if (a is double && b is double && a.isNaN && b.isNaN) return true;
    return a == b;
  }

  // ── actions ──────────────────────────────────────────────────────────────

  void _cycleSort(KkTableColumn<T> column) {
    final KkTableSort? now = _sortNow;
    final KkTableSort? next;
    if (now == null || now.column != column.id) {
      next = KkTableSort(column.id);
    } else if (now.ascending) {
      next = KkTableSort(column.id, KkSortDirection.descending);
    } else {
      next = null;
    }
    _reshuffle(() => _sort = next);
    widget.onSortChanged?.call(next);
  }

  void _onFilterChanged(String text) {
    // A new filter starts on the first page.
    final bool pageMoves = _viewNow.page != 0;
    _reshuffle(() => _page = 0);
    widget.onFilterChanged?.call(text);
    if (pageMoves) widget.onPageChanged?.call(0);
  }

  void _goToPage(int page) {
    if (page == _viewNow.page) return;
    _reshuffle(() => _page = page);
    widget.onPageChanged?.call(page);
  }

  void _setPageSize(int size) {
    final int? old = _sizeNow;
    if (size == old || size <= 0) return;
    // The row that was first on the page stays on the page.
    final int first = _viewNow.first;
    final int page = first ~/ size;
    final bool pageMoves = page != _viewNow.page;
    _reshuffle(() {
      _pageSize = size;
      _page = page;
    });
    widget.onPageSizeChanged?.call(size);
    if (pageMoves) widget.onPageChanged?.call(page);
  }

  void _setSelection(Set<Object> next) {
    setState(() => _selected = next);
    widget.onSelectionChanged?.call(next);
  }

  void _toggleSelected(Object key) {
    if (widget.selection == KkTableSelection.none) return;
    final Set<Object> now = _selectedExisting;
    final Set<Object> next;
    if (widget.selection == KkTableSelection.single) {
      next = now.contains(key) ? <Object>{} : <Object>{key};
    } else {
      next = Set<Object>.of(now);
      if (!next.remove(key)) next.add(key);
    }
    _anchorKey = key;
    _setSelection(next);
  }

  /// Selects every row from the last one that was toggled to [index].
  void _selectRangeTo(int index) {
    final _View<T> view = _viewNow;
    final int? anchor = _anchorKey == null ? null : view.indexOf[_anchorKey];
    if (widget.selection != KkTableSelection.multi || anchor == null) {
      _toggleSelected(view.keys[index]);
      return;
    }
    final Set<Object> next = Set<Object>.of(_selectedExisting);
    for (int i = math.min(anchor, index); i <= math.max(anchor, index); i++) {
      next.add(view.keys[i]);
    }
    _setSelection(next);
  }

  /// The state of the header checkbox: all rows of the page, none, or some.
  bool? get _pageSelection {
    final _View<T> view = _viewNow;
    final Set<Object> now = _selectedNow;
    if (view.keys.isEmpty || now.isEmpty) return false;
    int hit = 0;
    for (final Object key in view.keys) {
      if (now.contains(key)) hit++;
    }
    if (hit == 0) return false;
    return hit == view.keys.length ? true : null;
  }

  /// Selects the rows of the page, or clears them when all are selected.
  void _togglePage() {
    if (widget.selection != KkTableSelection.multi) return;
    final _View<T> view = _viewNow;
    final Set<Object> next = Set<Object>.of(_selectedExisting);
    if (_pageSelection ?? false) {
      next.removeAll(view.keys);
    } else {
      next.addAll(view.keys);
    }
    _setSelection(next);
  }

  bool _expandable(T row) => widget.detail != null && (widget.canExpand?.call(row) ?? true);

  void _setExpanded(Object key, bool open) {
    final Set<Object> now = _expandedNow;
    if (now.contains(key) == open) return;
    final Set<Object> next = Set<Object>.of(now);
    if (open) {
      next.add(key);
    } else {
      next.remove(key);
    }
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  /// A pointer went down on the row [key], on the row itself or on something
  /// in it: the keyboard carries on from there.
  void _rowPointerDown(Object key) {
    if (_focusedKey == key && !_showFocus) return;
    setState(() {
      _focusedKey = key;
      _showFocus = false;
    });
  }

  /// Gives the rows the keyboard, unless something inside them has it.
  void _focusBody() {
    if (_bodyFocus.canRequestFocus && !_bodyFocus.hasFocus) _bodyFocus.requestFocus();
  }

  /// Gives the rows the keyboard, standing on the row [key].
  void _handBack(Object key) {
    if (_focusedKey != key) setState(() => _focusedKey = key);
    if (_bodyFocus.canRequestFocus) _bodyFocus.requestFocus();
  }

  void _onRowTap(int index) {
    final _View<T> view = _viewNow;
    if (index < 0 || index >= view.rows.length) return;
    final Object key = view.keys[index];
    if (_bodyFocus.canRequestFocus) _bodyFocus.requestFocus();
    if (_focusedKey != key || _showFocus) {
      setState(() {
        _focusedKey = key;
        _showFocus = false;
      });
    }
    final ValueChanged<T>? pressed = widget.onRowPressed;
    if (pressed != null) {
      pressed(view.rows[index]);
    } else if (widget.selection != KkTableSelection.none) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _selectRangeTo(index);
      } else {
        _toggleSelected(key);
      }
    }
  }

  // ── keyboard ─────────────────────────────────────────────────────────────

  void _onFocusChanged() {
    final bool show = _bodyFocus.hasPrimaryFocus && KkInputModality.keyboard;
    Object? key = _focusedKey;
    if (_bodyFocus.hasPrimaryFocus) {
      // Arriving by keyboard without a row to stand on: take the first one
      // in view.
      final _View<T> view = _viewNow;
      if ((key == null || !view.indexOf.containsKey(key)) && view.keys.isNotEmpty) {
        final int at = _vertical.hasClients ? _link.rowAt(_vertical.offset) : 0;
        key = view.keys[at.clamp(0, view.keys.length - 1)];
      }
    }
    if (show != _showFocus || key != _focusedKey) {
      setState(() {
        _showFocus = show;
        _focusedKey = key;
      });
    }
  }

  void _focusRow(int index) {
    final _View<T> view = _viewNow;
    if (view.keys.isEmpty) return;
    final int i = index.clamp(0, view.keys.length - 1);
    setState(() {
      _focusedKey = view.keys[i];
      _showFocus = true;
    });
    _reveal(i);
  }

  /// Brings row [index] into view: in the table's own scroll by arithmetic
  /// (the row need not be built), in scroll views around the table by asking
  /// the row itself.
  void _reveal(int index) {
    if (_vertical.hasClients) {
      final ScrollPosition p = _vertical.position;
      final double top = _link.rowOffset(index);
      final double bottom = top + _link.rowExtent;
      double? target;
      if (top < p.pixels) {
        target = top;
      } else if (bottom > p.pixels + p.viewportDimension) {
        target = bottom - p.viewportDimension;
      }
      if (target != null) p.jumpTo(target.clamp(p.minScrollExtent, p.maxScrollExtent));
    }
    final Object key = _viewNow.keys[index];
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      final _KkTableRowState<T>? row = _mounted[key];
      if (row == null || !row.mounted) return;
      final RenderObject? box = row.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      // Only the part of the row that is on screen sideways, so that moving
      // up and down never scrolls the table sideways.
      double left = 0;
      double width = box.size.width;
      if (_horizontal.hasClients) {
        left = _horizontal.offset;
        width = math.min(width, _horizontal.position.viewportDimension);
      }
      box.showOnScreen(rect: Rect.fromLTWH(left, 0, width, _link.rowExtent), duration: Duration.zero);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  int get _rowsPerPage {
    if (!_vertical.hasClients) return 10;
    return math.max(1, (_vertical.position.viewportDimension / _link.rowExtent).floor() - 1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Keys typed into a cell (an editor, a button) are not for the rows.
    if (!node.hasPrimaryFocus || event is KeyUpEvent) return KeyEventResult.ignored;
    if (!_showFocus) setState(() => _showFocus = true);
    final _View<T> view = _viewNow;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      // Armed bulk actions stand down; the key goes on to whoever wants it.
      _disarm.fire();
      return KeyEventResult.ignored;
    }
    final int n = view.keys.length;
    if (n == 0) return KeyEventResult.ignored;
    final int current = _focusedKey == null ? -1 : (view.indexOf[_focusedKey] ?? -1);
    int? target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = current < 0 ? 0 : current + 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = current < 0 ? 0 : current - 1;
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = n - 1;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = (current < 0 ? 0 : current) + _rowsPerPage;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = (current < 0 ? 0 : current) - _rowsPerPage;
    }
    if (target != null) {
      _focusRow(target);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent || current < 0) return KeyEventResult.ignored;
    final T row = view.rows[current];
    final Object rowKey = view.keys[current];
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final ValueChanged<T>? pressed = widget.onRowPressed;
      if (pressed != null) {
        pressed(row);
        return KeyEventResult.handled;
      }
      if (_expandable(row)) {
        _setExpanded(rowKey, !_expandedNow.contains(rowKey));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.space) {
      if (widget.selection == KkTableSelection.none) return KeyEventResult.ignored;
      if (keyboard.isShiftPressed) {
        _selectRangeTo(current);
      } else {
        _toggleSelected(rowKey);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && _expandable(row) && !_expandedNow.contains(rowKey)) {
      _setExpanded(rowKey, true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && _expandedNow.contains(rowKey)) {
      _setExpanded(rowKey, false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA &&
        (keyboard.isControlPressed || keyboard.isMetaPressed) &&
        widget.selection == KkTableSelection.multi) {
      final Set<Object> next = Set<Object>.of(_selectedExisting)..addAll(view.keys);
      _setSelection(next);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── build ────────────────────────────────────────────────────────────────

  bool get _dense => widget.dense;
  double get _rowExtent => widget.rowHeight ?? (_dense ? 24 : 32);

  bool get _checkboxes =>
      widget.selection != KkTableSelection.none &&
      (widget.showCheckboxes ?? widget.selection == KkTableSelection.multi);

  List<_Col<T>> _columns() => <_Col<T>>[
    if (_checkboxes) _Col<T>.special(_ColKind.check, const KkTableWidth.fixed(36)),
    if (widget.showRowNumbers) _Col<T>.special(_ColKind.number, const KkTableWidth.fixed(40)),
    if (widget.detail != null) _Col<T>.special(_ColKind.expander, const KkTableWidth.fixed(28)),
    for (final KkTableColumn<T> c in widget.columns) _Col<T>.data(c),
  ];

  Alignment _alignmentOf(KkTableAlign align) => switch (align) {
    KkTableAlign.start => Alignment.centerLeft,
    KkTableAlign.center => Alignment.center,
    KkTableAlign.end => Alignment.centerRight,
  };

  List<Widget> _headerCells(List<_Col<T>> cols, KkColors c) {
    final KkTableSort? sort = _sortNow;
    return <Widget>[
      for (final _Col<T> col in cols)
        switch (col.kind) {
          _ColKind.check => KkBox(
            padding: const EdgeInsets.only(left: 8),
            alignment: Alignment.centerLeft,
            clip: true,
            child: widget.selection == KkTableSelection.multi
                ? KkCheckbox(
                    value: _pageSelection,
                    tristate: true,
                    onChanged: _viewNow.keys.isEmpty ? null : (bool? _) => _togglePage(),
                    semanticLabel: 'Select all rows on this page',
                  )
                : null,
          ),
          _ColKind.number => KkBox(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerRight,
            clip: true,
            child: KkText.en(
              widget.rowNumberLabel,
              size: 11,
              weight: FontWeight.w600,
              spacing: 0.06,
              upper: false,
              color: c.inkDim,
            ),
          ),
          _ColKind.expander => const KkBox(),
          _ColKind.data => KkBox(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: _alignmentOf(col.column!.alignment),
            clip: true,
            child: KkTableHeaderLabel(
              cjk: col.column!.cjk,
              en: col.column!.en,
              unit: col.column!.unit,
              end: col.column!.alignment == KkTableAlign.end,
              sort: (sort != null && sort.column == col.column!.id && col.column!.sortable) ? sort.direction : null,
              onSort: (col.column!.sortable && (col.column!.compare != null || col.column!.value != null))
                  ? () => _cycleSort(col.column!)
                  : null,
              tooltip: col.column!.tooltip,
              squeeze: widget.squeeze,
              semanticLabel: col.column!.label,
            ),
          ),
        },
    ];
  }

  List<Widget> _summaryCells(BuildContext context, List<_Col<T>> cols, List<T> rows) => <Widget>[
    for (final _Col<T> col in cols)
      if (col.column?.summary == null)
        const KkBox()
      else
        KkBox(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: _alignmentOf(col.column!.alignment),
          clip: true,
          child: Builder(builder: (BuildContext context) => col.column!.summary!(context, rows)),
        ),
  ];

  Widget _skeletonRow(List<_Col<T>> cols, KkColors c, int index) {
    return KkTableRowItem(
      link: _link,
      rowKey: index,
      rowExtent: _rowExtent,
      row: Semantics(
        role: SemanticsRole.row,
        label: 'Loading',
        child: ExcludeSemantics(
          child: KkTableCells(
            link: _link,
            height: _rowExtent,
            look: _skeletonLook(c),
            children: <Widget>[
              for (final _Col<T> col in cols)
                if (col.kind != _ColKind.data)
                  const KkBox()
                else
                  KkBox(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: KkRow(
                      children: <Widget>[
                        KkExpanded(
                          child: KkBox(
                            height: 8,
                            fill: c.bg200,
                            clip: true,
                            child: KkScanBar(color: c.signalDim, period: const Duration(milliseconds: 1400), steps: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  final KkTableRowPaint _skeletonPaint = KkTableRowPaint();

  KkTableRowPaint _skeletonLook(KkColors c) => _skeletonPaint..setLook(lineBottom: c.bg200);

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final _View<T> view = _viewNow;
    final List<_Col<T>> cols = _columns();
    final double rowExtent = _rowExtent;
    final bool two = widget.columns.any((KkTableColumn<T> col) => col.cjk?.isNotEmpty ?? false);
    final double headerHeight = two ? (_dense ? 36 : 42) : (_dense ? 24 : 30);
    final bool hasSummary = widget.columns.any((KkTableColumn<T> col) => col.summary != null);
    final double summaryHeight = hasSummary ? 30 : 0;
    final bool skeleton = widget.loading && view.rows.isEmpty && widget.skeletonRows > 0;
    final bool empty = view.rows.isEmpty && !skeleton;
    final Set<Object> expandedNow = _expandedNow;

    _link.configure(
      <KkTableWidth>[for (final _Col<T> col in cols) col.width],
      '${_dense ? 'd' : 'r'}|${theme.type.scale}|${<String>[for (final _Col<T> col in cols) col.column?.id ?? '#${col.kind.name}'].join('\u0000')}',
    );
    final List<int> openRows = <int>[];
    final List<Object> openKeys = <Object>[];
    if (!skeleton && widget.detail != null && expandedNow.isNotEmpty) {
      for (int i = 0; i < view.rows.length; i++) {
        if (expandedNow.contains(view.keys[i]) && _expandable(view.rows[i])) {
          openRows.add(i);
          openKeys.add(view.keys[i]);
        }
      }
    }
    final int count = skeleton ? widget.skeletonRows : view.rows.length;
    if (_link.setRows(count: count, rowExtent: rowExtent, expanded: openRows, expandedKeys: openKeys)) {
      _rowsVersion++;
    }
    _link.retainDetails(openKeys.toSet());

    _headerLook.setLook(background: c.bg200, lineBottom: c.line, lineWidth: m.stroke1);
    _summaryLook.setLook(background: c.bg200, lineTop: c.line, lineWidth: m.stroke1);

    final TextStyle cellStyle = theme.type.mono(_dense ? 11 : 12, height: 1.4, color: c.ink);

    final Widget header = KkTableCells(
      link: _link,
      height: headerHeight,
      header: true,
      look: _headerLook,
      children: _headerCells(cols, c),
    );

    Widget? body;
    if (!empty) {
      body = Focus(
        focusNode: _bodyFocus,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: CustomScrollView(
          controller: _vertical,
          primary: false,
          physics: const _RowPhysics(),
          semanticChildCount: count,
          slivers: <Widget>[
            KkTableRowsSliver(
              link: _link,
              version: _rowsVersion,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (skeleton) return index < count ? _skeletonRow(cols, c, index) : null;
                  if (index < 0 || index >= view.rows.length) return null;
                  final Object key = view.keys[index];
                  final T row = view.rows[index];
                  return _KkTableRow<T>(
                    key: ValueKey<Object>(key),
                    table: this,
                    view: view,
                    columns: cols,
                    index: index,
                    row: row,
                    rowKey: key,
                    selected: _selectedNow.contains(key),
                    focused: _showFocus && _focusedKey == key,
                    expanded: expandedNow.contains(key),
                    flashes: _flashes[key],
                    shifts: _shifts[key] ?? 0,
                    entrance: widget.entrance && _entranceOpen,
                    generation: _generation,
                    cellStyle: cellStyle,
                  );
                },
                childCount: count,
                addAutomaticKeepAlives: false,
                findChildIndexCallback: (Key key) {
                  if (skeleton || key is! ValueKey<Object>) return null;
                  return view.indexOf[key.value];
                },
              ),
            ),
          ],
        ),
      );
    }

    final Widget? summary = hasSummary
        ? DefaultTextStyle(
            style: theme.type.mono(12, weight: FontWeight.w500, color: c.ink),
            child: KkTableCells(
              link: _link,
              height: summaryHeight,
              // A content column is wide enough for its summary too.
              measure: true,
              look: _summaryLook,
              children: _summaryCells(context, cols, view.filtered),
            ),
          )
        : null;

    final Widget grid = KkTableGrid(
      link: _link,
      headerHeight: headerHeight,
      summaryHeight: summaryHeight,
      header: header,
      body: body,
      summary: summary,
    );

    RawScrollbar bar({
      required ScrollController controller,
      required ScrollbarOrientation orientation,
      required int depth,
      EdgeInsets padding = EdgeInsets.zero,
      required Widget child,
    }) {
      final Axis axis = orientation == ScrollbarOrientation.bottom ? Axis.horizontal : Axis.vertical;
      return RawScrollbar(
        controller: controller,
        thumbColor: c.line,
        thickness: 6,
        radius: Radius.zero,
        minThumbLength: 24,
        fadeDuration: Duration.zero,
        timeToFade: const Duration(milliseconds: 900),
        scrollbarOrientation: orientation,
        padding: padding,
        notificationPredicate: (ScrollNotification n) => n.depth == depth && n.metrics.axis == axis,
        child: child,
      );
    }

    // The thumbs sit at the edges of the table, not of the scrolled content:
    // the upright one stays in sight while the table is scrolled sideways.
    final Widget area = ScrollConfiguration(
      behavior: const KkScrollBehavior(showScrollbars: false),
      child: bar(
        controller: _horizontal,
        orientation: ScrollbarOrientation.bottom,
        depth: 0,
        child: bar(
          controller: _vertical,
          orientation: ScrollbarOrientation.right,
          depth: 1,
          padding: EdgeInsets.only(top: headerHeight, bottom: summaryHeight),
          child: KkScroll(axis: Axis.horizontal, controller: _horizontal, child: grid),
        ),
      ),
    );

    final Set<Object> selectedExisting = _selectedExisting;
    final bool hasBand =
        widget.showBand ??
        (widget.code != null ||
            widget.cjk != null ||
            widget.en != null ||
            widget.meta != null ||
            widget.filterable ||
            widget.actions.isNotEmpty ||
            widget.bulkActions.isNotEmpty ||
            widget.selection == KkTableSelection.multi);
    final Widget? band = hasBand
        ? KkTableBand(
            code: widget.code,
            cjk: widget.cjk,
            en: widget.en,
            meta: widget.meta,
            squeeze: widget.squeeze,
            filter: widget.filterable
                ? KkTableFilterField(
                    controller: _filterController,
                    placeholder: widget.filterPlaceholder,
                    onChanged: _onFilterChanged,
                  )
                : null,
            actions: widget.actions,
            // One selected row is "the current row", not a batch to act on:
            // only a multiple selection takes the band over.
            selected: widget.selection == KkTableSelection.multi ? selectedExisting : const <Object>{},
            selectionCjk: widget.selectionCjk,
            selectionEn: widget.selectionEn,
            bulkActions: widget.bulkActions,
            onClearSelection: () => _setSelection(<Object>{}),
            disarm: _disarm,
          )
        : null;

    final Widget rail = KkBox(
      height: m.stroke2,
      fill: widget.loading ? c.signalDim : null,
      clip: true,
      child: widget.loading ? KkScanBar(color: c.signal, period: const Duration(milliseconds: 1200), steps: 12) : null,
    );

    final int? size = _sizeNow;
    final bool hasFooter = widget.showFooter ?? (size != null);
    Widget? footer;
    if (hasFooter) {
      final int digits = math.max(3, view.total.toString().length);
      String pad(int n) => n.toString().padLeft(digits, '0');
      final String range;
      if (view.total == 0 || view.rows.isEmpty) {
        range = '${pad(0)} / ${pad(view.total)}';
      } else if (size == null) {
        range = '${pad(view.total)} ROWS';
      } else {
        range = '${pad(view.first + 1)}–${pad(view.first + view.rows.length)} / ${pad(view.total)}';
      }
      final bool narrowed = !_server && view.filtered.length != widget.rows.length;
      footer = KkTableFooter(
        text: narrowed ? '$range · OF ${widget.rows.length}' : range,
        pageSize: size,
        pageSizeOptions: widget.pageSizeOptions,
        onPageSizeChanged: _setPageSize,
        page: view.page,
        pageCount: view.pageCount,
        onPageChanged: _goToPage,
      );
    }

    Widget? emptyBlock;
    if (empty) {
      final Widget Function(BuildContext context, bool noMatch)? custom = widget.emptyBuilder;
      emptyBlock = custom != null
          ? Builder(builder: (BuildContext context) => custom(context, view.noMatch))
          : _EmptyBlock(
              cjk: view.noMatch ? widget.noMatchCjk : widget.emptyCjk,
              en: view.noMatch ? widget.noMatchEn : widget.emptyEn,
              squeeze: widget.squeeze,
            );
    }

    final int selectedCount = widget.selection == KkTableSelection.multi ? selectedExisting.length : 0;
    final Widget live = Semantics(
      container: true,
      liveRegion: true,
      label: selectedCount == 0 ? '' : '$selectedCount ${selectedCount == 1 ? 'row' : 'rows'} selected',
      child: const KkBox(),
    );

    Widget table = KkBox(
      decoration: KkDecoration(
        fill: widget.fill ?? c.bg100,
        edges: widget.frame ? KkEdges.line(c.line, width: m.stroke1) : KkEdges.none,
      ),
      child: KkTableFrame(
        link: _link,
        headerHeight: headerHeight,
        summaryHeight: summaryHeight,
        band: band,
        rail: rail,
        area: area,
        empty: emptyBlock,
        footer: footer,
        live: live,
      ),
    );
    if (widget.boot) table = KkBoot(child: table);
    final String label = widget.semanticLabel ?? <String>[?widget.code, ?widget.cjk, ?widget.en].join(' ');
    return Semantics(container: true, label: label.isEmpty ? null : label, child: table);
  }
}

/// The block a table shows in place of its rows.
class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.cjk, required this.en, required this.squeeze});

  final String cjk;
  final String en;
  final double squeeze;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    return KkBox(
      padding: EdgeInsets.all(m.space6),
      edges: KkEdges(bottom: KkSide(c.bg200, width: m.stroke1)),
      child: KkColumn(
        shrinkWrap: true,
        gap: m.space2,
        cross: KkCrossAlign.center,
        children: <Widget>[
          if (cjk.isNotEmpty) KkText.cjk(cjk, size: 26, color: c.inkDim, squeeze: squeeze),
          if (en.isNotEmpty) KkText.en(en, size: 11, weight: FontWeight.w700, spacing: 0.16, color: c.inkFaint),
        ],
      ),
    );
  }
}

// ── one body row ───────────────────────────────────────────────────────────

class _KkTableRow<T> extends StatefulWidget {
  const _KkTableRow({
    super.key,
    required this.table,
    required this.view,
    required this.columns,
    required this.index,
    required this.row,
    required this.rowKey,
    required this.selected,
    required this.focused,
    required this.expanded,
    required this.flashes,
    required this.shifts,
    required this.entrance,
    required this.generation,
    required this.cellStyle,
  });

  final _KkDataTableState<T> table;
  final _View<T> view;
  final List<_Col<T>> columns;
  final int index;
  final T row;
  final Object rowKey;
  final bool selected;
  final bool focused;
  final bool expanded;

  /// How often each tracked column of this row has changed so far.
  final List<int>? flashes;

  /// How often the level of this row has changed so far.
  final int shifts;
  final bool entrance;
  final int generation;
  final TextStyle cellStyle;

  @override
  State<_KkTableRow<T>> createState() => _KkTableRowState<T>();
}

class _KkTableRowState<T> extends State<_KkTableRow<T>> with SingleTickerProviderStateMixin {
  final KkTableRowPaint _look = KkTableRowPaint();
  Ticker? _ticker;
  Duration _now = Duration.zero;

  /// When the flash of each data column started (ticker time), by tracked
  /// column position.
  final Map<int, Duration> _flashStart = <int, Duration>{};
  Duration? _shiftStart;
  bool _hovered = false;

  // The palette of the last build, for changes that do not rebuild.
  Color? _ground;
  Color? _hoverGround;
  Color? _fillColor;
  double _fill = 0;
  Color? _line;
  Color? _focus;
  Color _flashHot = const Color(0x00000000);
  Color _flashCool = const Color(0x00000000);
  Color _shiftColor = const Color(0x00000000);
  double _timeScale = 1;
  bool _motion = true;

  KkDataTable<T> get _table => widget.table.widget;

  @override
  void initState() {
    super.initState();
    widget.table._mounted[widget.rowKey] = this;
  }

  @override
  void didUpdateWidget(_KkTableRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowKey != widget.rowKey) {
      if (identical(widget.table._mounted[oldWidget.rowKey], this)) widget.table._mounted.remove(oldWidget.rowKey);
      widget.table._mounted[widget.rowKey] = this;
      _flashStart.clear();
      _shiftStart = null;
      return;
    }
    final List<int>? before = oldWidget.flashes;
    final List<int>? now = widget.flashes;
    bool started = false;
    if (now != null) {
      for (int i = 0; i < now.length; i++) {
        final int old = (before != null && i < before.length) ? before[i] : 0;
        if (now[i] != old) {
          _flashStart[i] = _now;
          started = true;
        }
      }
    }
    if (widget.shifts != oldWidget.shifts) {
      _shiftStart = _now;
      started = true;
    }
    if (started) _run();
  }

  @override
  void dispose() {
    if (identical(widget.table._mounted[widget.rowKey], this)) widget.table._mounted.remove(widget.rowKey);
    _ticker?.dispose();
    _look.dispose();
    super.dispose();
  }

  // ── effects ──────────────────────────────────────────────────────────────

  void _run() {
    if (!_motion) {
      _flashStart.clear();
      _shiftStart = null;
      return;
    }
    final Ticker ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      // The ticker's clock starts again at zero: move what is running back.
      final Duration offset = _now;
      _flashStart.updateAll((int _, Duration start) => start - offset);
      final Duration? shift = _shiftStart;
      if (shift != null) _shiftStart = shift - offset;
      _now = Duration.zero;
      ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    _paintEffects();
    if (_flashStart.isEmpty && _shiftStart == null) _ticker?.stop();
  }

  double _progress(Duration start, Duration length) {
    final int total = (length.inMicroseconds * _timeScale).round();
    if (total <= 0) return 1;
    return (_now - start).inMicroseconds / total;
  }

  /// The colours of the running effects at the current time.
  void _paintEffects() {
    Color? shift;
    final Duration? shiftStart = _shiftStart;
    if (shiftStart != null) {
      final double t = _progress(shiftStart, _rowShiftTime);
      if (t >= 1) {
        _shiftStart = null;
      } else {
        // Three strobes: on for a sixth, off for a sixth.
        final int phase = (t * 100 / 17).floor();
        if (phase.isEven && phase < 5) shift = _shiftColor;
      }
    }
    List<Color?> flashes = const <Color?>[];
    if (_flashStart.isNotEmpty) {
      final List<_Col<T>> cols = widget.columns;
      flashes = List<Color?>.filled(cols.length, null);
      final List<int> done = <int>[];
      _flashStart.forEach((int tracked, Duration start) {
        final double t = _progress(start, _cellFlashTime);
        if (t >= 1) {
          done.add(tracked);
          return;
        }
        final int at = _columnOfTracked(tracked);
        if (at < 0) return;
        // signal, then signal-dim at a quarter of the time, then clear; six
        // steps in each part.
        flashes[at] = t < 0.25
            ? Color.lerp(_flashHot, _flashCool, kkStepDown(t / 0.25, 6))
            : _flashCool.withValues(alpha: _flashCool.a * (1 - kkStepDown((t - 0.25) / 0.75, 6)));
      });
      done.forEach(_flashStart.remove);
      if (_flashStart.isEmpty) flashes = const <Color?>[];
    }
    _look.setEffects(shift: shift, flashes: flashes);
  }

  /// The position among all columns of the [tracked]-th column with a value.
  int _columnOfTracked(int tracked) {
    int seen = -1;
    final List<_Col<T>> cols = widget.columns;
    for (int i = 0; i < cols.length; i++) {
      if (cols[i].column?.value == null) continue;
      seen++;
      if (seen == tracked) return i;
    }
    return -1;
  }

  // ── look ─────────────────────────────────────────────────────────────────

  void _applyLook() {
    _look.setLook(
      background: _ground ?? (_hovered ? _hoverGround : null),
      fillColor: _fillColor,
      fill: _fill,
      lineBottom: _line,
      focus: _focus,
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _applyLook();
  }

  Alignment _alignmentOf(KkTableAlign align) => switch (align) {
    KkTableAlign.start => Alignment.centerLeft,
    KkTableAlign.center => Alignment.center,
    KkTableAlign.end => Alignment.centerRight,
  };

  Widget _cell(BuildContext context, _Col<T> col, KkColors c, bool critical) {
    final _KkDataTableState<T> table = widget.table;
    final T row = widget.row;
    switch (col.kind) {
      case _ColKind.check:
        return Semantics(
          container: true,
          role: SemanticsRole.cell,
          child: KkBox(
            padding: const EdgeInsets.only(left: 8),
            alignment: Alignment.centerLeft,
            clip: true,
            // The row itself is the keyboard's way to select (Space).
            child: ExcludeFocus(
              child: KkCheckbox(
                value: widget.selected,
                onChanged: (bool? _) {
                  table._focusBody();
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    table._selectRangeTo(widget.index);
                  } else {
                    table._toggleSelected(widget.rowKey);
                  }
                },
                semanticLabel: 'Select row',
              ),
            ),
          ),
        );
      case _ColKind.number:
        final int digits = math.max(2, widget.view.total.toString().length);
        return Semantics(
          container: true,
          role: SemanticsRole.cell,
          child: KkBox(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerRight,
            clip: true,
            child: KkText.num(
              (widget.view.first + widget.index + 1).toString().padLeft(digits, '0'),
              size: 11,
              color: critical ? c.ink : c.inkDim,
            ),
          ),
        );
      case _ColKind.expander:
        final bool can = table._expandable(row);
        return Semantics(
          container: true,
          role: SemanticsRole.cell,
          child: KkBox(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            clip: true,
            child: can
                ? ExcludeFocus(
                    child: KkIconButton(
                      icon: widget.expanded ? KkIcons.chevronDown : KkIcons.chevronRight,
                      size: KkIconButtonSize.sm,
                      iconSize: 12,
                      semanticLabel: widget.expanded ? 'Collapse row' : 'Expand row',
                      onPressed: () {
                        table._focusBody();
                        table._setExpanded(widget.rowKey, !widget.expanded);
                      },
                    ),
                  )
                : null,
          ),
        );
      case _ColKind.data:
        final KkTableColumn<T> column = col.column!;
        final Widget Function(BuildContext context, T row)? builder = column.cell;
        final Widget content = builder != null
            ? Builder(builder: (BuildContext context) => builder(context, row))
            : KkText(
                column.textOf(row),
                maxLines: 1,
                softWrap: false,
                overflow: column.truncate ? TextOverflow.ellipsis : TextOverflow.clip,
              );
        final Alignment alignment = _alignmentOf(column.alignment);
        final Widget cell;
        if (column.editableFor(row)) {
          final KkTableCellRef? open = _table.initiallyEditing;
          cell = KkTableEditCell(
            text: () => column.editText?.call(row) ?? column.textOf(row),
            validator: column.validator == null ? null : (String text) => column.validator!(row, text),
            onCommit: (String text) => column.onEdited!(row, text),
            onClosed: (bool committed, bool hadFocus) {
              // Enter and Escape hand the keyboard back to the rows.
              if (hadFocus) table._handBack(widget.rowKey);
            },
            commitOnBlur: column.commitOnBlur,
            alignment: alignment,
            formatters: column.editFormatters,
            keyboardType: column.editKeyboardType,
            maxLength: column.editMaxLength,
            initiallyEditing: open != null && open.rowKey == widget.rowKey && open.column == column.id,
            semanticLabel: 'Edit ${column.label}',
            child: content,
          );
        } else {
          cell = KkBox(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: alignment,
            clip: true,
            child: content,
          );
        }
        return Semantics(container: true, role: SemanticsRole.cell, label: column.label, child: cell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final _KkDataTableState<T> table = widget.table;
    final KkDataTable<T> config = _table;
    final T row = widget.row;
    final KkLevel? level = config.rowLevel?.call(row);
    final bool critical = level == KkLevel.critical;
    final double? rawFill = config.rowFill?.call(row);
    final double fill = (rawFill == null || rawFill.isNaN) ? 0 : rawFill.clamp(0.0, 1.0);
    final Color fillColor = kkMix(c.signal, 0.18, c.bg100);

    _motion = KeikaiTheme.motionOf(context);
    _timeScale = theme.motion.timeScale;
    _flashHot = c.signal;
    _flashCool = c.signalDim;
    _shiftColor = kkFade(c.level(level), 0.45);
    // Later rules win: critical over a full fill over selected over hover.
    _ground = critical ? c.alertDeep : (fill >= 1 ? fillColor : (widget.selected ? c.bg300 : null));
    _hoverGround = c.bg200;
    _fillColor = (!critical && fill > 0 && fill < 1) ? fillColor : null;
    _fill = fill;
    _line = c.bg200;
    _focus = widget.focused ? c.focus : null;
    _applyLook();
    if (_flashStart.isNotEmpty || _shiftStart != null) {
      if (_motion) {
        // The first frame of an effect is the frame of the change, in the
        // colours of this build.
        _paintEffects();
      } else {
        _flashStart.clear();
        _shiftStart = null;
        _look.setEffects();
      }
    }

    final bool pressable = config.onRowPressed != null || config.selection != KkTableSelection.none;
    Widget cells = KkTableCells(
      link: table._link,
      height: table._rowExtent,
      measure: true,
      look: _look,
      children: <Widget>[for (final _Col<T> col in widget.columns) _cell(context, col, c, critical)],
    );
    cells = KkTableRowScope(
      level: level,
      dense: config.dense,
      selected: widget.selected,
      child: DefaultTextStyle(style: widget.cellStyle, child: cells),
    );
    cells = MouseRegion(
      cursor: pressable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (PointerEnterEvent _) => _setHovered(true),
      onExit: (PointerExitEvent _) => _setHovered(false),
      child: Listener(
        // Whatever in the row takes the press, the row becomes the one the
        // keyboard stands on.
        onPointerDown: (PointerDownEvent _) => table._rowPointerDown(widget.rowKey),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => table._onRowTap(widget.index),
          child: cells,
        ),
      ),
    );
    if (config.entrance) {
      cells = KkFlicker(
        duration: _rowFlickerTime,
        keyframes: _rowFlicker,
        delay: Duration(milliseconds: 35 * math.min<int>(widget.index, _entranceRows) + 250),
        trigger: widget.generation,
        enabled: widget.entrance,
        child: cells,
      );
    }
    cells = Semantics(
      role: SemanticsRole.row,
      label: config.rowSemanticLabel?.call(row),
      selected: config.selection == KkTableSelection.none ? null : widget.selected,
      onTap: pressable ? () => table._onRowTap(widget.index) : null,
      child: cells,
    );

    Widget? detail;
    final Widget Function(BuildContext context, T row)? buildDetail = config.detail;
    if (widget.expanded && buildDetail != null && table._expandable(row)) {
      detail = Semantics(
        container: true,
        role: SemanticsRole.cell,
        child: KkBox(
          decoration: KkDecoration(
            fill: c.bg000,
            edges: KkEdges(bottom: KkSide(c.line, width: m.stroke1)),
          ),
          clip: true,
          child: KkBoot(
            duration: const Duration(milliseconds: 300),
            steps: 6,
            stagger: false,
            child: KkLayers(
              children: <Widget>[
                KkBox(
                  padding: EdgeInsets.fromLTRB(m.space8, m.space3, m.space4, m.space3),
                  alignment: Alignment.topLeft,
                  child: DefaultTextStyle(
                    style: theme.type.mono(12, height: 1.6, color: c.inkDim),
                    child: Builder(builder: (BuildContext context) => buildDetail(context, row)),
                  ),
                ),
                // The corner mark.
                KkPositioned(
                  left: m.space4,
                  top: m.space3,
                  width: 8,
                  height: 8,
                  child: KkBox(
                    edges: KkEdges(
                      left: KkSide(c.signal, width: m.stroke2),
                      top: KkSide(c.signal, width: m.stroke2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return KkTableRowItem(
      link: table._link,
      rowKey: widget.rowKey,
      rowExtent: table._rowExtent,
      row: cells,
      detail: detail,
    );
  }
}
