// Dart imports:
import 'dart:async';
import 'dart:core';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:native_device_orientation/native_device_orientation.dart';

// Project imports:
import 'package:zego_uikit/src/components/audio_video/avatar/avatar.dart';
import 'package:zego_uikit/src/components/audio_video/defines.dart';
import 'package:zego_uikit/src/components/defines.dart';
import 'package:zego_uikit/src/components/internal/internal.dart';
import 'package:zego_uikit/src/components/screen_util/screen_util.dart';
import 'package:zego_uikit/src/components/widgets/flip_animation.dart';
import 'package:zego_uikit/src/services/internal/core/core.dart';
import 'package:zego_uikit/src/services/services.dart';

/// display user audio and video information,
/// and z order of widget(from bottom to top) is:
/// 1. background view
/// 2. video view
/// 3. foreground view
class ZegoAudioVideoView extends StatefulWidget {
  const ZegoAudioVideoView({
    Key? key,
    required this.user,
    this.backgroundBuilder,
    this.foregroundBuilder,
    this.borderRadius,
    this.borderColor,
    this.extraInfo,
    this.avatarConfig,
  }) : super(key: key);

  final ZegoUIKitUser? user;

  /// foreground builder, you can display something you want on top of the view,
  /// foreground will always show
  final ZegoAudioVideoViewForegroundBuilder? foregroundBuilder;

  /// background builder, you can display something when user close camera
  final ZegoAudioVideoViewBackgroundBuilder? backgroundBuilder;

  final double? borderRadius;
  final Color? borderColor;
  final Map<String, dynamic>? extraInfo;

  final ZegoAvatarConfig? avatarConfig;

  @override
  State<ZegoAudioVideoView> createState() => _ZegoAudioVideoViewState();
}

class _ZegoAudioVideoViewState extends State<ZegoAudioVideoView> {
  Timer? viewIDGuardTimer;
  final isLocalUserFlippedNotifier = ValueNotifier<bool>(false);

  int get userViewID => ZegoUIKit().getAudioVideoViewID(widget.user!.id);
  bool get userViewIDIsEmpty => -1 == userViewID;

  ZegoUIKitCoreUser get localUserData =>
      ZegoUIKitCore.shared.coreData.localUser;

  List<StreamSubscription<dynamic>?> subscriptions = [];

  @override
  void initState() {
    super.initState();

    subscriptions
      ..add(ZegoUIKit().getUserListStream().listen(onUserListUpdated))
      ..add(ZegoUIKit()
          .getAudioVideoListStream()
          .listen(onAudioVideoListUpdated));
  }

  @override
  void dispose() {
    viewIDGuardTimer?.cancel();

    for (final subscription in subscriptions) {
      subscription?.cancel();
    }

    super.dispose();
  }

  void onUserListUpdated(List<ZegoUIKitUser> users) {
    setState(() {});
  }

  void onAudioVideoListUpdated(List<ZegoUIKitUser> users) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (ZegoUIKit().getUser(widget.user?.id ?? '').isEmpty()) {
      ZegoLoggerService.logInfo(
        '${widget.user?.id} is null',
        tag: 'uikit-component',
        subTag: 'audio video view',
      );

      return SizedBox.expand(
        child: Stack(
          children: [
            background(),
            foreground(),
          ],
        ),
      );
    }

    final view = circleBorder(
      child: ValueListenableBuilder<bool>(
        valueListenable:
            ZegoUIKit().getCameraStateNotifier(widget.user?.id ?? ''),
        builder: (context, isCameraOn, _) {
          ZegoLoggerService.logInfo(
            '${widget.user?.id}\'s camera changed $isCameraOn,',
            tag: 'uikit-component',
            subTag: 'audio video view',
          );

          return isCameraOn
              ? Stack(
                  children: [
                    background(),
                    videoView(
                      isCameraOn: isCameraOn,
                    ),
                    foreground(),
                  ],
                )
              : Stack(
                  children: [
                    videoView(
                      isCameraOn: isCameraOn,
                    ),
                    background(),
                    foreground(),
                  ],
                );
        },
      ),
    );

    final isLocalUser =
        null != widget.user && ZegoUIKit().getLocalUser().id == widget.user?.id;
    return SizedBox.expand(
      child: isLocalUser ? localCameraFlipAnimation(view) : view,
    );
  }

  Widget localCameraFlipAnimation(Widget child) {
    /// local user, camera switch animation
    return ValueListenableBuilder<bool>(
      valueListenable: localUserData.isFrontFacing,
      builder: (context, isReadyFrontFacing, _) {
        localUserData.mainChannel.isCapturedVideoFirstFrame
            .addListener(onCapturedVideoFirstFrameAfterSwitchCamera);

        return ZegoUIKitFlipTransition(
          key: ValueKey(localUserData.id),
          isFlippedNotifier: isLocalUserFlippedNotifier,
          isFrontTriggerByTurnOnCamera:
              localUserData.isFrontTriggerByTurnOnCamera,
          child: ValueListenableBuilder<bool>(
            valueListenable:
                localUserData.mainChannel.isRenderedVideoFirstFrame,
            builder: (context, isRenderedVideoFirstFrame, _) {
              return isRenderedVideoFirstFrame
                  ? child
                  : Stack(
                      children: [
                        child,

                        /// it was an overlay of the rendered frame, but the current video frame could not be obtained
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.withOpacity(0.05),
                                Colors.black.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    );
            },
          ),
        );
      },
    );
  }

  void onCapturedVideoFirstFrameAfterSwitchCamera() {
    ZegoUIKitCore
        .shared.coreData.localUser.mainChannel.isCapturedVideoFirstFrame
        .removeListener(onCapturedVideoFirstFrameAfterSwitchCamera);

    isLocalUserFlippedNotifier.value = !isLocalUserFlippedNotifier.value;

    ZegoLoggerService.logInfo(
      'onCapturedVideoFirstFrameAfterSwitchCamera',
      tag: 'uikit-component',
      subTag: 'audio video view',
    );
  }

  Widget videoView({
    required bool isCameraOn,
  }) {
    return userViewListenerBuilder(
      childBuilder: (Widget audioVideoView) {
        if (!isCameraOn) {
          viewIDGuardTimer?.cancel();
          viewIDGuardTimer = null;
        } else if (userViewIDIsEmpty) {
          runViewIDTimeGuard();
        }

        return ZegoUIKit().getUser(widget.user!.id).isEmpty()
            ? Container()
            : LayoutBuilder(
                builder: (context, constraints) {
                  ZegoLoggerService.logInfo(
                    '${widget.user?.id}\'s constraints changed,'
                    'width:${constraints.maxWidth}, '
                    'height:${constraints.maxHeight}, ',
                    tag: 'uikit-component',
                    subTag: 'audio video view',
                  );

                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: isCameraOn
                        ? audioVideoView
                        : Container(color: Colors.transparent),
                  );
                },
              );
      },
    );
  }

  Widget userViewListenerBuilder({
    required Widget Function(
      Widget audioVideoView,
    ) childBuilder,
  }) {
    return ValueListenableBuilder<Widget?>(
      valueListenable: ZegoUIKit().getAudioVideoViewNotifier(widget.user!.id),
      builder: (context, userView, _) {
        if (userView == null) {
          ZegoLoggerService.logError(
            '${widget.user?.id}\'s view is null',
            tag: 'uikit-component',
            subTag: 'audio video view',
          );

          /// hide video view when use not found
          return Container(color: Colors.transparent);
        }

        ZegoLoggerService.logInfo(
          'render ${widget.user?.id}\'s view ${userView.hashCode}',
          tag: 'uikit-component',
          subTag: 'audio video view',
        );

        return deviceOrientationListenerBuilder(
          child: childBuilder(userView),
        );
      },
    );
  }

  Widget deviceOrientationListenerBuilder({
    required Widget child,
  }) {
    return StreamBuilder(
      stream: NativeDeviceOrientationCommunicator().onOrientationChanged(),
      builder: (context, AsyncSnapshot<NativeDeviceOrientation> asyncResult) {
        if (asyncResult.hasData) {
          /// Do not update ui when ui is building !!!
          /// use postFrameCallback to update videoSize
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ///  notify sdk to update video render orientation
            ZegoUIKit().updateAppOrientation(
              deviceOrientationMap(asyncResult.data!),
            );
          });
        }

        return child;
      },
    );
  }

  Widget background() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: ZegoUIKitUserPropertiesNotifier(
                widget.user ?? ZegoUIKitUser.empty(),
              ),
              builder: (context, _, __) {
                return widget.backgroundBuilder?.call(
                      context,
                      Size(constraints.maxWidth, constraints.maxHeight),
                      widget.user,
                      widget.extraInfo ?? {},
                    ) ??
                    Container(color: Colors.transparent);
              },
            ),
            avatar(constraints.maxWidth, constraints.maxHeight),
          ],
        );
      },
    );
  }

  Widget foreground() {
    if (widget.foregroundBuilder != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(children: [
            ValueListenableBuilder(
              valueListenable: ZegoUIKitUserPropertiesNotifier(
                widget.user ?? ZegoUIKitUser.empty(),
              ),
              builder: (context, _, __) {
                return widget.foregroundBuilder!.call(
                  context,
                  Size(constraints.maxWidth, constraints.maxHeight),
                  widget.user,
                  widget.extraInfo ?? {},
                );
              },
            ),
          ]);
        },
      );
    }

    return Container(color: Colors.transparent);
  }

  Widget circleBorder({required Widget child}) {
    if (widget.borderRadius == null) {
      return child;
    }

    final decoration = BoxDecoration(
      border: Border.all(
          color: widget.borderColor ?? const Color(0xffA4A4A4), width: 1),
      borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius!)),
    );

    return Container(
      decoration: decoration,
      child: PhysicalModel(
        color: widget.borderColor ?? const Color(0xffA4A4A4),
        borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius!)),
        clipBehavior: Clip.antiAlias,
        elevation: 6.0,
        shadowColor:
            (widget.borderColor ?? const Color(0xffA4A4A4)).withOpacity(0.3),
        child: child,
      ),
    );
  }

  Widget avatar(double maxWidth, double maxHeight) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallView = maxHeight < screenSize.height / 2;
    final avatarSize =
        isSmallView ? Size(110.zR, 110.zR) : Size(258.zR, 258.zR);

    var sizedWidth = widget.avatarConfig?.size?.width ?? avatarSize.width;
    var sizedHeight = widget.avatarConfig?.size?.height ?? avatarSize.width;
    if (sizedWidth > maxWidth) {
      sizedWidth = maxWidth;
    }
    if (sizedHeight > maxHeight) {
      sizedHeight = maxHeight;
    }

    return Positioned(
      top: getAvatarTop(maxWidth, maxHeight, sizedHeight),
      left: (maxWidth - sizedWidth) / 2,
      child: SizedBox(
        width: sizedWidth,
        height: sizedHeight,
        child: ZegoAvatar(
          avatarSize: widget.avatarConfig?.size ?? avatarSize,
          user: widget.user,
          showAvatar: widget.avatarConfig?.showInAudioMode ?? true,
          showSoundLevel:
              widget.avatarConfig?.showSoundWavesInAudioMode ?? true,
          avatarBuilder: widget.avatarConfig?.builder,
          soundLevelSize: widget.avatarConfig?.size,
          soundLevelColor: widget.avatarConfig?.soundWaveColor,
        ),
      ),
    );
  }

  double getAvatarTop(double maxWidth, double maxHeight, double avatarHeight) {
    switch (
        widget.avatarConfig?.verticalAlignment ?? ZegoAvatarAlignment.center) {
      case ZegoAvatarAlignment.center:
        return (maxHeight - avatarHeight) / 2;
      case ZegoAvatarAlignment.start:
        return 15.zR; //  sound level height
      case ZegoAvatarAlignment.end:
        return maxHeight - avatarHeight;
    }
  }

  void runViewIDTimeGuard() {
    ZegoLoggerService.logInfo(
      'guard run, ${widget.user?.id}\'s view id is:$userViewID',
      tag: 'uikit-component',
      subTag: 'audio video view',
    );

    viewIDGuardTimer?.cancel();
    viewIDGuardTimer = null;

    viewIDGuardTimer ??=
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      ZegoLoggerService.logInfo(
        'guard check, ${widget.user?.id}\'s view id is:$userViewID',
        tag: 'uikit-component',
        subTag: 'audio video view',
      );

      if (!userViewIDIsEmpty) {
        viewIDGuardTimer?.cancel();
      } else {
        ZegoLoggerService.logInfo(
          'guard check, ${widget.user?.id}\'s view-id($userViewID) is not valid now, force update',
          tag: 'uikit-component',
          subTag: 'audio video view',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {});
        });
      }
    });
  }
}
