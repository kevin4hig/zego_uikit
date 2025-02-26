part of 'uikit_service.dart';

/// @nodoc
mixin ZegoEventService {
  void enableEventUninitOnRoomLeaved(bool enabled) {
    ZegoUIKitCore.shared.event.enableUninitOnRoomLeaved(enabled);
  }

  void registerExpressEvent(ZegoUIKitExpressEventInterface event) {
    ZegoUIKitCore.shared.event.express.register(event);
  }

  void unregisterExpressEvent(ZegoUIKitExpressEventInterface event) {
    ZegoUIKitCore.shared.event.express.unregister(event);
  }
}
