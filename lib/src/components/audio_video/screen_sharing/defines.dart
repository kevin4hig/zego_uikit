// Flutter imports:
import 'package:flutter/material.dart';

class ZegoScreenSharingCountDownStopSettings {
  bool support = false;
  String tips = 'screen sharing may have ended and will automatically stop';
  int seconds = 10;

  Color? textColor;
  Color? progressColor;
  double? secondFontSize;
  double? tipsFontSize;
  final countDownStartNotifier = ValueNotifier<bool>(false);
  VoidCallback? onCountDownFinished;
}

class ZegoScreenSharingAutoStopSettings {
  /// Count of the check fails before automatically end the screen sharing
  int invalidCount = 3;

  /// Determines whether to end;
  /// returns false if you don't want to end
  bool Function()? canEnd;
}
