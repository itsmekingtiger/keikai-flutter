import 'package:keikai/keikai.dart';

/// The page every catalogue sheet is laid out on: screen grid ground, a large
/// bilingual title with its code, then the sections.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.code,
    required this.cjk,
    required this.en,
    this.note,
    required this.sections,
  });

  /// Family code, such as `F-03`.
  final String code;
  final String cjk;
  final String en;

  /// One short sentence under the title.
  final String? note;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final String? n = note;
    return KkBackdrop(
      padding: const EdgeInsets.all(32),
      child: KkColumn(
        gap: 32,
        shrinkWrap: true,
        children: <Widget>[
          KkColumn(
            gap: 8,
            shrinkWrap: true,
            children: <Widget>[
              KkRow(
                gap: 12,
                cross: KkCrossAlign.baseline,
                children: <Widget>[
                  KkText.cjk(cjk, size: 44, squeeze: 0.8, color: c.ink),
                  KkText.en(en, size: 20, weight: FontWeight.w800, spacing: 0.06, color: c.inkDim),
                  const KkSpacer(),
                  KkText.num(code, size: 11, weight: FontWeight.w600, spacing: 0.08, color: c.signal),
                ],
              ),
              KkBox(height: 2, fill: c.signal),
              if (n != null) KkText.body(n, size: 12, height: 1.5, color: c.inkDim),
            ],
          ),
          ...sections,
        ],
      ),
    );
  }
}

/// One titled block of a sheet: a ruled label (code, CJK, EN) and its content.
class SheetSection extends StatelessWidget {
  const SheetSection({super.key, required this.code, this.cjk, required this.en, required this.child});

  /// Section code, such as `C-01`.
  final String code;
  final String? cjk;
  final String en;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkColumn(
      gap: 16,
      shrinkWrap: true,
      children: <Widget>[
        KkRow(
          gap: 8,
          children: <Widget>[
            KkText.num(code, size: 10, weight: FontWeight.w500, color: c.signal),
            KkLabel(cjk: cjk, en: en, cjkSize: 12, enSize: 10, enSpacing: 0.16, gap: 6),
            KkExpanded(child: KkBox(height: 1, fill: c.line)),
          ],
        ),
        child,
      ],
    );
  }
}

/// A captioned specimen inside a section: the widget, with a small mono
/// caption under it.
class SheetItem extends StatelessWidget {
  const SheetItem({super.key, required this.caption, this.width, required this.child});

  final String caption;

  /// Fixed width for the specimen; by default it takes its natural width.
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    return KkBox(
      width: width,
      child: KkColumn(
        gap: 8,
        shrinkWrap: true,
        cross: width == null ? KkCrossAlign.start : KkCrossAlign.stretch,
        children: <Widget>[
          child,
          KkText.num(caption, size: 10, color: c.inkFaint),
        ],
      ),
    );
  }
}
