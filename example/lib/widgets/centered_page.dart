import 'package:keikai/keikai.dart';

/// A page that stands alone, without the console's frame around it: its
/// content sits in the middle of the screen ground, clear of a notch, and
/// scrolls when the window is too short for it (a phone held sideways).
class CenteredPage extends StatefulWidget {
  const CenteredPage({super.key, this.maxWidth = 520, required this.builder});

  /// The content is never wider than this.
  final double maxWidth;

  /// Builds the content. [short] is true in a window under 440px high, where
  /// the content should keep its lines close together.
  final Widget Function(BuildContext context, bool short) builder;

  @override
  State<CenteredPage> createState() => _CenteredPageState();
}

class _CenteredPageState extends State<CenteredPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KkBackdrop(
      // No KkScreen here to do it: the page keeps clear of a notch by itself.
      child: KkSafeArea(
        child: KkBreakpoint(
          builder: (BuildContext context, KkWindowClass windowClass, BoxConstraints constraints) {
            final bool short = constraints.maxHeight < 440;
            return KkScroll(
              controller: _scroll,
              // At least as tall as the window, so that content that fits
              // stands in the middle of it.
              child: KkBox(
                minHeight: constraints.maxHeight,
                padding: EdgeInsets.all(short ? 12 : 24),
                alignment: Alignment.center,
                child: KkBox(maxWidth: widget.maxWidth, child: widget.builder(context, short)),
              ),
            );
          },
        ),
      ),
    );
  }
}
