/// KEIKAI 警戒 for Flutter: a dark HQ/HUD design language.
///
/// Import this one library to build a whole app. It re-exports the framework's
/// widgets layer (`State`, `BuildContext`, `Navigator` …) the same way
/// `material.dart` does, so no other import is needed.
library;

// What an app needs from the services layer besides widgets: keys, the
// clipboard, text-input types and formatters, and the system chrome.
export 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        DeviceOrientation,
        FilteringTextInputFormatter,
        HapticFeedback,
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LengthLimitingTextInputFormatter,
        LogicalKeyboardKey,
        PhysicalKeyboardKey,
        SystemChrome,
        SystemNavigator,
        SystemSound,
        SystemSoundType,
        SystemUiMode,
        SystemUiOverlayStyle,
        TextCapitalization,
        TextEditingValue,
        TextInputAction,
        TextInputFormatter,
        TextInputType;
export 'package:flutter/widgets.dart';

export 'src/app/app.dart';
export 'src/app/routes.dart';
export 'src/charts/charts.dart';
export 'src/controls/controls.dart';
export 'src/diagram/diagram.dart';
export 'src/foundation/colors.dart';
export 'src/foundation/icons.dart';
export 'src/foundation/level.dart';
export 'src/foundation/motion.dart';
export 'src/foundation/theme.dart';
export 'src/foundation/tokens.dart';
export 'src/foundation/typography.dart';
export 'src/hud/hud.dart';
export 'src/inputs/inputs.dart';
export 'src/layout/layout.dart';
export 'src/motion/effects.dart';
export 'src/motion/entrances.dart';
export 'src/motion/loops.dart';
export 'src/motion/scramble.dart';
export 'src/motion/stagger.dart';
export 'src/painting/decoration.dart';
export 'src/painting/patterns.dart';
export 'src/painting/shapes.dart';
export 'src/painting/svg_path.dart';
export 'src/painting/text.dart';
export 'src/shell/shell.dart';
export 'src/table/table.dart';
export 'src/widgets/clock.dart';
export 'src/widgets/frame.dart';
export 'src/widgets/icon.dart';
export 'src/widgets/pressable.dart';
export 'src/widgets/text.dart';
