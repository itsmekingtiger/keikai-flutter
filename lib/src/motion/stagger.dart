import 'package:flutter/widgets.dart';

/// Carries an index down the tree so entrance animations can start one after
/// another. A grid gives each cell its position; a panel in cell 3 therefore
/// boots 180ms after the panel in cell 0.
class KkStagger extends InheritedWidget {
  const KkStagger({super.key, required this.index, required super.child});

  final int index;

  /// The nearest index, or 0.
  static int of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<KkStagger>()?.index ?? 0;

  @override
  bool updateShouldNotify(KkStagger oldWidget) => oldWidget.index != index;
}
