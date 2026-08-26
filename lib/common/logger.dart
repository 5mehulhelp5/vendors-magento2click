import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'extensions.dart';

class CustomLog extends FlutterTalkerLog {
  CustomLog(String message) : super(message);

  @override
  AnsiPen get pen => AnsiPen()..xterm(49);

  @override
  Color get color => Colors.teal;

  @override
  String generateTextMessage() {
    return '| Custom leading | $message';
  }
}

enum TalkerType { fine, info, verbose, warning, logTyped, log }

/// One shared Talker for the whole app. The previous code built a brand-new
/// Talker (own history buffer + logger) on *every* call — including from inside
/// build() — so it now lives behind [kDebugMode] and a lazily-created
/// singleton, and does nothing in release.
Talker? _sharedTalker;
Talker get _talker => _sharedTalker ??= Talker(
      observers: [],
      settings: TalkerSettings(
        enabled: true,
        useHistory: true,
        maxHistoryItems: 100,
        useConsoleLogs: true,
      ),
      logger: TalkerLogger(
        output: (message) {
          message.log();
        },
      ),
    );

void logTalker({
  required String classFileName,
  required TalkerType logType,
  required String message,
}) {
  if (!kDebugMode) return;
  final tagged = '⏰⏰⏰ $classFileName 🌷🌷🌷 $message';
  switch (logType) {
    case TalkerType.fine:
      _talker.fine(tagged);
      break;
    case TalkerType.info:
      _talker.info(tagged);
      break;
    case TalkerType.verbose:
      _talker.verbose(tagged);
      break;
    case TalkerType.warning:
      _talker.warning(tagged);
      break;
    case TalkerType.logTyped:
    case TalkerType.log:
      _talker.log(CustomLog(tagged));
      break;
  }
}
