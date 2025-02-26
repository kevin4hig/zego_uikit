// Project imports:
import 'defines.dart';

class ZegoScreenSharingViewControllerPrivate {
  var countDownStopSettings = ZegoScreenSharingCountDownStopSettings();

  /// when ending screen sharing from a non-app,
  /// the automatic check end mechanism will be triggered.
  var autoStopSettings = ZegoScreenSharingAutoStopSettings();
}
