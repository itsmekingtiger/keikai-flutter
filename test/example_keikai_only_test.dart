import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Proves the claim of the example app: its whole interface is built from
/// KEIKAI widgets. Every constructor the example calls must belong to one of:
///
/// * `package:keikai` (names starting with `Kk` or `Keikai`),
/// * the example itself,
/// * [_values]: plain data, controllers and keys from Dart and the framework,
/// * [_plumbing]: framework widgets that draw nothing and lay nothing out.
///
/// A `Row`, `Container`, `Text`, `Padding`, `Stack` … anywhere fails the test.

/// Value classes, controllers and keys. None of these is a widget.
const Set<String> _values = <String>{
  'Alignment', 'ArgumentError', 'BigInt', 'BoxConstraints', 'ChangeNotifier', 'Color', 'Completer', 'DateTime',
  'Duration', 'EdgeInsets', 'Exception', 'FocusNode', 'FocusScopeNode', 'FormatException', 'Function', 'Future',
  'GlobalKey',
  'Iterable', 'List', 'Locale', 'Map', 'MapEntry', 'Object', 'ObjectKey', 'Offset', 'Point', 'Random', 'Rect',
  'RegExp', 'RouteSettings', 'ScrollController', 'Set', 'SingleActivator', 'Size', 'StateError', 'Stopwatch',
  'Stream', 'StreamController', 'String', 'StringBuffer', 'TextEditingController', 'TextEditingValue',
  'TextRange', 'TextSelection', 'TextStyle', 'Timer', 'UniqueKey', 'UnimplementedError', 'UnsupportedError',
  'Uri', 'ValueKey', 'ValueNotifier',
};

/// Framework widgets with no pixels and no layout of their own: state and
/// focus plumbing only.
const Set<String> _plumbing = <String>{
  'Actions', 'Builder', 'CallbackShortcuts', 'ExcludeSemantics', 'Focus', 'FocusScope', 'FutureBuilder',
  'KeyedSubtree', 'ListenableBuilder', 'MergeSemantics', 'PopScope', 'RepaintBoundary', 'Semantics',
  'Shortcuts', 'StatefulBuilder', 'StreamBuilder', 'ValueListenableBuilder',
};

/// Framework classes that may be used through static members only
/// (`Navigator.of(context)`), never constructed.
const Set<String> _staticOnly = <String>{
  'Clipboard', 'ClipboardData', 'DefaultTextStyle', 'Directionality', 'FocusManager', 'HapticFeedback',
  'MediaQuery', 'Navigator', 'Overlay', 'SchedulerBinding', 'ServicesBinding', 'SystemChrome', 'SystemNavigator',
  'TickerMode', 'WidgetsBinding',
};

/// Removes comments and string literals so only code is scanned.
String _stripCommentsAndStrings(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  final int n = src.length;
  while (i < n) {
    final String c = src[i];
    final String next = i + 1 < n ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      int depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (src.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (src.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          if (src[i] == '\n') out.write('\n');
          i++;
        }
      }
      continue;
    }
    final bool raw = (c == 'r') && (next == "'" || next == '"') && (i == 0 || !RegExp(r'[A-Za-z0-9_]').hasMatch(src[i - 1]));
    if (c == "'" || c == '"' || raw) {
      if (raw) i++;
      final String q = src[i];
      final bool triple = src.startsWith(q * 3, i);
      i += triple ? 3 : 1;
      while (i < n) {
        if (!raw && src[i] == r'\') {
          i += 2;
          continue;
        }
        if (!raw && src[i] == r'$' && i + 1 < n && src[i + 1] == '{') {
          // Skip the interpolated expression, honouring nested braces.
          int depth = 1;
          i += 2;
          while (i < n && depth > 0) {
            if (src[i] == '{') depth++;
            if (src[i] == '}') depth--;
            i++;
          }
          continue;
        }
        if (triple ? src.startsWith(q * 3, i) : src[i] == q) {
          i += triple ? 3 : 1;
          break;
        }
        if (src[i] == '\n') out.write('\n');
        i++;
      }
      out.write("''");
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

void main() {
  test('the example app is built with KEIKAI widgets only', () {
    final Directory dir = Directory('example/lib');
    expect(dir.existsSync(), isTrue, reason: 'run from the package root');
    final List<File> files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final Map<String, String> code = <String, String>{
      for (final File f in files) f.path: _stripCommentsAndStrings(f.readAsStringSync()),
    };

    // Everything the example declares itself.
    final Set<String> declared = <String>{};
    final RegExp declaration = RegExp(
      r'\b(?:class|enum|mixin|typedef|extension\s+type|extension)\s+([A-Z][A-Za-z0-9_]*)',
    );
    for (final String text in code.values) {
      for (final RegExpMatch m in declaration.allMatches(text)) {
        declared.add(m.group(1)!);
      }
    }

    final List<String> problems = <String>[];

    // 1. Imports: Dart core libraries, the one KEIKAI library, or the example's own files.
    final RegExp import = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);
    for (final File f in files) {
      for (final RegExpMatch m in import.allMatches(f.readAsStringSync())) {
        final String uri = m.group(1)!;
        final bool ok =
            uri.startsWith('dart:') || uri == 'package:keikai/keikai.dart' || !uri.contains(':');
        if (!ok) problems.add('${f.path}: imports $uri');
      }
    }

    // 2. Constructor calls: `Name(`, `Name<T>(`, `Name.named(`, `const Name(`.
    final RegExp call = RegExp(r'\b([A-Z][A-Za-z0-9_]*)\s*(?:<[^()<>;{}]*>)?\s*(\.\s*[a-zA-Z_][A-Za-z0-9_]*)?\s*\(');
    code.forEach((String path, String text) {
      for (final RegExpMatch m in call.allMatches(text)) {
        final String name = m.group(1)!;
        final bool viaMember = m.group(2) != null;
        // A declaration such as `class Foo extends Bar {` never ends in `(`,
        // and a method declared on a type is lower-case, so every hit is a use.
        if (name.startsWith('Kk') || name.startsWith('Keikai')) continue;
        if (declared.contains(name)) continue;
        if (_values.contains(name) || _plumbing.contains(name)) continue;
        if (viaMember && _staticOnly.contains(name)) continue;
        final int line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
        problems.add('$path:$line uses $name${m.group(2) ?? ''}(…), which is not a KEIKAI widget');
      }
    });

    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
