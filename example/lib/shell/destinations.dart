import 'package:keikai/keikai.dart';

/// The seven screens of the console, in rail order.
enum Destination {
  situation(route: '/', key: '1', cjk: '状況', en: 'situation', label: 'board', icon: KkIcons.grid),
  systems(route: '/systems', key: '2', cjk: '系統', en: 'systems', label: 'systems', icon: KkIcons.server),
  diagram(route: '/diagram', key: '3', cjk: '線図', en: 'diagram', label: 'diagram', icon: KkIcons.node),
  procedure(route: '/procedure', key: '4', cjk: '手順', en: 'procedure', label: 'steps', icon: KkIcons.list),
  log(route: '/log', key: '5', cjk: '記録', en: 'log', label: 'log', icon: KkIcons.terminal),
  settings(route: '/settings', key: '6', cjk: '設定', en: 'settings', label: 'setup', icon: KkIcons.sliders),
  catalogue(route: '/catalogue', key: '7', cjk: '目録', en: 'catalogue', label: 'index', icon: KkIcons.layers);

  const Destination({
    required this.route,
    required this.key,
    required this.cjk,
    required this.en,
    required this.label,
    required this.icon,
  });

  /// The route name, which is also the path in the browser's address bar.
  final String route;

  /// The digit key that jumps here.
  final String key;
  final String cjk;
  final String en;

  /// The one short word under the rail icon.
  final String label;
  final KkIconData icon;

  /// The destination a route name stands for, or null when it names none.
  static Destination? fromRoute(String? name) {
    for (final Destination d in values) {
      if (d.route == name) return d;
    }
    return null;
  }
}

/// The route name of the full-screen alarm.
const String emergencyRoute = '/emergency';

/// Shows [destination]. The situation board is the root of the stack; every
/// other screen sits right on top of it, so Back always leads to the board.
void goTo(BuildContext context, Destination destination) {
  final NavigatorState navigator = Navigator.of(context);
  if (destination == Destination.situation) {
    navigator.popUntil((Route<Object?> route) => route.isFirst);
  } else {
    navigator.pushNamedAndRemoveUntil(destination.route, (Route<Object?> route) => route.isFirst);
  }
}
