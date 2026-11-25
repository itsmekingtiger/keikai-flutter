import 'package:keikai/keikai.dart';

void main() => runApp(const KeikaiExampleApp());

class KeikaiExampleApp extends StatelessWidget {
  const KeikaiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeikaiApp(
      title: 'KEIKAI',
      home: KkBackdrop(
        alignment: Alignment.center,
        child: KkLabel(cjk: '警戒', en: 'keikai for flutter', cjkSize: 44, enSize: 13),
      ),
    );
  }
}
