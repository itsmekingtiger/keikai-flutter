import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../charts/format.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../inputs/select.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// A pager: first, previous, `03 / 12`, next, last.
///
/// [page] counts from zero. The buttons that would leave the range are off;
/// with no [onChanged] all of them are. This is the pager in the footer of a
/// `KkDataTable`, usable on its own under any paged list.
class KkPagination extends StatelessWidget {
  const KkPagination({
    super.key,
    required this.page,
    required this.pageCount,
    this.onChanged,
    this.showEnds = true,
    this.enabled = true,
    this.semanticLabel = 'Pages',
  });

  /// The current page, from 0. A value outside the range is shown as the
  /// nearest page.
  final int page;

  /// The number of pages. 0 shows `00 / 00` with every button off.
  final int pageCount;

  /// Called with the page a button leads to.
  final ValueChanged<int>? onChanged;

  /// Show the first and last buttons.
  final bool showEnds;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final int count = math.max(0, pageCount);
    final int current = count == 0 ? 0 : page.clamp(0, count - 1);
    final int digits = math.max(2, count.toString().length);
    final ValueChanged<int>? go = enabled ? onChanged : null;
    final bool back = go != null && current > 0;
    final bool forward = go != null && current < count - 1;

    Widget button(KkIconData icon, String label, bool live, int target) => KkIconButton(
      icon: icon,
      size: KkIconButtonSize.sm,
      semanticLabel: label,
      onPressed: live ? () => go!(target) : null,
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      value: count == 0 ? 'No pages' : 'Page ${current + 1} of $count',
      child: KkRow(
        shrinkWrap: true,
        gap: 2,
        children: <Widget>[
          if (showEnds) button(KkIcons.first, 'First page', back, 0),
          button(KkIcons.chevronLeft, 'Previous page', back, current - 1),
          ExcludeSemantics(
            child: KkBox(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: KkRow(
                shrinkWrap: true,
                cross: KkCrossAlign.baseline,
                children: <Widget>[
                  KkText.num(
                    kkFixed(count == 0 ? 0 : current + 1, digits: digits),
                    size: 11,
                    weight: FontWeight.w500,
                    color: go == null ? c.inkFaint : c.ink,
                  ),
                  KkText.num(
                    ' / ${kkFixed(count, digits: digits)}',
                    size: 11,
                    color: go == null ? c.inkFaint : c.inkDim,
                  ),
                ],
              ),
            ),
          ),
          button(KkIcons.chevronRight, 'Next page', forward, current + 1),
          if (showEnds) button(KkIcons.last, 'Last page', forward, count - 1),
        ],
      ),
    );
  }
}

/// The footer of a table: the range of rows shown, the rows-per-page select
/// and the pager.
///
/// This class is not part of the public API.
class KkTableFooter extends StatelessWidget {
  const KkTableFooter({
    super.key,
    required this.text,
    this.pageSize,
    this.pageSizeOptions = const <int>[],
    this.onPageSizeChanged,
    this.page = 0,
    this.pageCount = 0,
    this.onPageChanged,
    this.perPageLabel = 'rows',
    this.trailing = const <Widget>[],
  });

  /// The range text at the left (`001–025 / 128`).
  final String text;
  final int? pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;
  final int page;
  final int pageCount;
  final ValueChanged<int>? onPageChanged;
  final String perPageLabel;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final int? size = pageSize;
    // The current size is always among the choices.
    final List<int> sizes = <int>{...pageSizeOptions.where((int n) => n > 0), ?size}.toList()..sort();
    return KkBox(
      height: 36,
      padding: EdgeInsets.only(left: m.space3, right: m.space1),
      edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
      clip: true,
      child: KkRow(
        gap: m.space3,
        children: <Widget>[
          KkExpanded(
            child: KkText.num(text, size: 11, color: c.inkDim, overflow: TextOverflow.ellipsis),
          ),
          ...trailing,
          if (size != null && sizes.length > 1 && onPageSizeChanged != null)
            KkRow(
              shrinkWrap: true,
              gap: 6,
              children: <Widget>[
                KkText.num(perPageLabel.toUpperCase(), size: 11, spacing: 0.1, color: c.inkDim),
                KkSelect<int>(
                  size: KkSelectSize.xs,
                  value: size,
                  onChanged: onPageSizeChanged,
                  semanticLabel: 'Rows per page',
                  options: <KkSelectOption<int>>[
                    for (final int n in sizes) KkSelectOption<int>(value: n, label: n.toString()),
                  ],
                ),
              ],
            ),
          if (size != null) KkPagination(page: page, pageCount: pageCount, onChanged: onPageChanged),
        ],
      ),
    );
  }
}
