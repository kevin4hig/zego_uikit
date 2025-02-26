part of 'uikit_service.dart';

mixin ZegoDeviceService {
  /// protocol: String is 'operator'
  Stream<String> getTurnOnYourCameraRequestStream() {
    return ZegoUIKitCore
            .shared.coreData.turnOnYourCameraRequestStreamCtrl?.stream ??
        const Stream.empty();
  }

  Stream<ZegoUIKitReceiveTurnOnLocalMicrophoneEvent>
      getTurnOnYourMicrophoneRequestStream() {
    return ZegoUIKitCore
            .shared.coreData.turnOnYourMicrophoneRequestStreamCtrl?.stream ??
        const Stream.empty();
  }

  void enableCustomVideoProcessing(bool enable) {
    ZegoUIKitCore.shared.enableCustomVideoProcessing(enable);
  }

  ZegoMobileSystemVersion getMobileSystemVersion() {
    var systemVersion = ZegoMobileSystemVersion.empty();

    String version = Platform.operatingSystemVersion;
    if (Platform.isAndroid) {
      final RegExp versionRegExp = RegExp(r'(\d+)\.(\d+)\.(\d+)');
      final match = versionRegExp.firstMatch(version);
      if (match != null) {
        systemVersion.major = int.parse(match.group(1)!);
        systemVersion.minor = int.parse(match.group(2)!);
      }
    } else if (Platform.isIOS) {
      final RegExp versionRegExp = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?');
      final match = versionRegExp.firstMatch(version);

      if (match != null) {
        systemVersion.major = int.parse(match.group(1)!);
        systemVersion.minor = int.parse(match.group(2)!);
        if (match.group(3) != null) {
          systemVersion.patch = int.parse(match.group(3)!);
        }
      }
    }

    return systemVersion;
  }
}
