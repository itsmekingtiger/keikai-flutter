import 'package:keikai/keikai.dart';

import '../widgets/centered_page.dart';
import 'destinations.dart';

/// Shown for an address that names no screen.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.name});

  /// The route name that was asked for.
  final String name;

  @override
  Widget build(BuildContext context) {
    return CenteredPage(
      builder: (BuildContext context, bool short) => KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          const KkHazard(level: KkLevel.offline, height: 8),
          KkEmpty.noSignal(
            cjk: '経路なし',
            en: 'no route',
            sub: name.isEmpty ? 'UNKNOWN ADDRESS' : 'NOTHING AT $name',
            action: KkButton(
              label: 'return to board',
              cjk: '復帰',
              icon: KkIcons.home,
              autofocus: true,
              onPressed: () => goTo(context, Destination.situation),
            ),
          ),
        ],
      ),
    );
  }
}
