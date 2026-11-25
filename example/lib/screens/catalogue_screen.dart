import 'package:keikai/keikai.dart';

import '../sheets/charts_sheet.dart';
import '../sheets/controls_sheet.dart';
import '../sheets/diagram_sheet.dart';
import '../sheets/foundation_sheet.dart';
import '../sheets/hud_sheet.dart';
import '../sheets/inputs_sheet.dart';
import '../sheets/layout_sheet.dart';
import '../sheets/shell_sheet.dart';
import '../sheets/table_sheet.dart';
import '../shell/destinations.dart';
import '../widgets/screen_header.dart';

/// One family of the catalogue.
class _Family {
  const _Family(this.code, this.cjk, this.en, this.sheet);

  final String code;
  final String cjk;
  final String en;
  final Widget sheet;
}

const List<_Family> _families = <_Family>[
  _Family('F-01', '基盤', 'foundation', FoundationSheet()),
  _Family('F-02', '配置', 'layout', LayoutSheet()),
  _Family('F-03', '操作', 'controls', ControlsSheet()),
  _Family('F-04', '入力', 'inputs', InputsSheet()),
  _Family('F-05', '航法', 'shell', ShellSheet()),
  _Family('F-06', '計測', 'instruments', HudSheet()),
  _Family('F-07', '図表', 'charts', ChartsSheet()),
  _Family('F-08', '線図', 'diagrams', DiagramSheet()),
  _Family('F-09', '表', 'table', TableSheet()),
];

/// Width the sheets are drawn at.
const double _sheetWidth = 1440;

/// The body height from which the title and the tabs are pinned above the
/// sheet. Below it they scroll away with the sheet.
const double _pinnedMinHeight = 420;

/// Every widget of the language, family by family, as the catalogue sheets
/// that the package's own golden tests render.
class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();
  int _index = 0;

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// Shows family [i] from its top-left corner.
  void _show(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _toCorner();
  }

  /// Puts the sheet's top-left corner in view.
  ///
  /// It is called again once a new sheet has settled: a sheet that shows a menu
  /// open makes the page scroll to that menu and hands it the keyboard, and
  /// the operator has not gone there yet.
  void _toCorner() {
    if (_vertical.hasClients) _vertical.jumpTo(0);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final _Family family = _families[_index];
    final Widget header = ScreenHeader(
      destination: Destination.catalogue,
      trail: <KkCrumb>[KkCrumb(code: family.code, cjk: family.cjk, en: family.en)],
      note: '위젯 전부를 계열별 견본지로 본다. 견본지는 폭 1440px로 그려지며 가로 · 세로로 밀어 볼 수 있다.',
      actions: <Widget>[
        KkIconButton(
          icon: KkIcons.chevronLeft,
          variant: KkIconButtonVariant.outline,
          semanticLabel: 'Previous family',
          onPressed: _index > 0 ? () => _show(_index - 1) : null,
        ),
        KkIconButton(
          icon: KkIcons.chevronRight,
          variant: KkIconButtonVariant.outline,
          semanticLabel: 'Next family',
          onPressed: _index < _families.length - 1 ? () => _show(_index + 1) : null,
        ),
      ],
    );
    final Widget tabs = KkTabs(
      index: _index,
      onChanged: _show,
      tabs: <KkTab>[for (final _Family f in _families) KkTab(code: f.code.substring(2), cjk: f.cjk, en: f.en)],
    );
    final Widget sheet = KkScroll(
      axis: Axis.horizontal,
      controller: _horizontal,
      child: _SheetStage(key: ValueKey<String>(family.code), sheet: family.sheet, onReady: _toCorner),
    );
    return KkBreakpoint(
      builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
        // In a short window (a phone held sideways) the title and the tabs
        // would leave no room for the sheet: there the whole page scrolls.
        if (constraints.maxHeight < _pinnedMinHeight) {
          return KkScroll(
            controller: _vertical,
            child: KkColumn(gap: 12, shrinkWrap: true, children: <Widget>[header, tabs, sheet]),
          );
        }
        // Otherwise the title and the tabs stay put and the sheet scrolls
        // both ways under them.
        return KkColumn(
          gap: 12,
          children: <Widget>[
            header,
            tabs,
            KkExpanded(
              child: KkScroll(controller: _vertical, child: sheet),
            ),
          ],
        );
      },
    );
  }
}

/// Shows one sheet at its full size on a layer of its own.
///
/// A sheet keeps some of its menus, lists and tooltips open to show them.
/// Those float on the nearest overlay, and the app's overlay covers the
/// window: scrolled away from their anchors' place they would pile up at the
/// window's edges, over the command bar and the tabs. So each sheet gets an
/// overlay exactly as large as itself (a `KeikaiApp` of its own brings one),
/// and the scroll views move sheet and overlay together.
class _SheetStage extends StatefulWidget {
  const _SheetStage({super.key, required this.sheet, required this.onReady});

  final Widget sheet;

  /// Called once, when the sheet has been measured and shown at its size.
  final VoidCallback onReady;

  @override
  State<_SheetStage> createState() => _SheetStageState();
}

class _SheetStageState extends State<_SheetStage> {
  /// Room for the first frame, before the sheet has been measured.
  static const double _unmeasured = 6400;

  final GlobalKey _sheet = GlobalKey(debugLabel: 'catalogue sheet');
  double? _height;
  bool _ready = false;

  /// Reads the sheet's own height once it is laid out and takes it over.
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final Size? size = _sheet.currentContext?.size;
      if (size == null || !size.height.isFinite || size.height <= 0) return;
      final double height = size.height.ceilToDouble();
      if (height != _height) {
        setState(() => _height = height);
      } else if (!_ready) {
        _ready = true;
        _release();
        widget.onReady();
      }
    });
  }

  /// Takes the keyboard back from a control of the sheet that grabbed it on
  /// its own (an example menu that is shown open).
  void _release() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.findAncestorStateOfType<_SheetStageState>() == this) focus!.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = context.kk;
    // A change of type scale or theme changes the sheet's height.
    _measure();
    return KkSized(
      width: _sheetWidth,
      height: _height ?? _unmeasured,
      child: KeikaiApp(
        title: 'KEIKAI 管制 · HQ-03',
        theme: theme,
        condition: theme.condition,
        glitchOnAlert: false,
        wallScale: false,
        home: KkAlign(
          alignment: Alignment.topLeft,
          child: KeyedSubtree(key: _sheet, child: widget.sheet),
        ),
      ),
    );
  }
}
