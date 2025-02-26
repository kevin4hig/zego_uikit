// Dart imports:
import 'dart:core';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:zego_uikit/src/components/components.dart';
import 'package:zego_uikit/src/components/internal/internal.dart';
import 'package:zego_uikit/src/components/outside_room_audio_video/internal.dart';
import 'package:zego_uikit/src/services/services.dart';

/// display user audio and video information without join room(live/conference),
/// and z order of widget(from bottom to top) is:
/// 1. background view
/// 2. video view
/// 3. foreground view
class ZegoOutsideRoomAudioVideoViewList extends StatefulWidget {
  const ZegoOutsideRoomAudioVideoViewList({
    Key? key,
    required this.appID,
    required this.controller,
    this.appSign = '',
    this.token = '',
    this.scenario = ZegoScenario.Default,
    ZegoOutsideRoomAudioVideoViewListStyle? style,
    ZegoOutsideRoomAudioVideoViewListConfig? config,
  })  : style = style ?? const ZegoOutsideRoomAudioVideoViewListStyle(),
        config = config ?? const ZegoOutsideRoomAudioVideoViewListConfig(),
        super(key: key);

  /// You can create a project and obtain an appID from the [ZEGOCLOUD Admin Console](https://console.zegocloud.com).
  final int appID;

  /// log in by using [appID] + [appSign].
  ///
  /// You can create a project and obtain an appSign from the [ZEGOCLOUD Admin Console](https://console.zegocloud.com).
  ///
  /// Of course, you can also log in by using [appID] + [token]. For details, see [token].
  final String appSign;

  /// log in by using [appID] + [token].
  ///
  /// The token issued by the developer's business server is used to ensure security.
  /// Please note that if you want to use [appID] + [token] login, do not assign a value to [appSign]
  ///
  /// For the generation rules, please refer to [Using Token Authentication] (https://doc-zh.zego.im/article/10360), the default is an empty string, that is, no authentication.
  ///
  /// if appSign is not passed in or if appSign is empty, this parameter must be set for authentication when logging in to a room.
  final String token;

  ///
  final ZegoScenario scenario;

  ///  style
  final ZegoOutsideRoomAudioVideoViewListStyle style;

  /// config
  final ZegoOutsideRoomAudioVideoViewListConfig config;

  /// controller
  final ZegoOutsideRoomAudioVideoViewListController controller;

  @override
  State<ZegoOutsideRoomAudioVideoViewList> createState() =>
      _ZegoOutsideRoomAudioVideoViewListState();
}

class _ZegoOutsideRoomAudioVideoViewListState
    extends State<ZegoOutsideRoomAudioVideoViewList> {
  @override
  void initState() {
    super.initState();

    widget.controller.private.setData(
      appID: widget.appID,
      appSign: widget.appSign,
      token: widget.token,
      scenario: widget.scenario,
      config: widget.config,
    );
    widget.controller.private.init().then((_) {
      if (ZegoOutsideRoomAudioVideoViewListPlayMode.autoPlay ==
          widget.config.playMode) {
        widget.controller.private.forceUpdate();
      } else {
        ZegoLoggerService.logInfo(
          'play mode is not auto',
          tag: 'outside room audio video view',
          subTag: 'outside room audio video view',
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    widget.controller.private.uninit().then((_) {
      widget.controller.private.clearData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZegoScreenUtilInit(
      designSize: const Size(750, 1334),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return sdkInitWrapper(
          child: roomLoginWrapper(
            child: ValueListenableBuilder(
              valueListenable: widget.controller.private.updateNotifier,
              builder: (context, _, __) {
                return listview();
              },
            ),
          ),
        );
      },
    );
  }

  Widget listview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = Axis.horizontal == widget.style.scrollDirection
            ? (1 / widget.style.item.sizeAspectRatio * constraints.maxHeight)
                .ceil()
                .toDouble()
            : constraints.maxWidth;
        final itemHeight = Axis.horizontal == widget.style.scrollDirection
            ? constraints.maxHeight
            : (widget.style.item.sizeAspectRatio * constraints.maxWidth)
                .ceil()
                .toDouble();

        ZegoLoggerService.logInfo(
          'layout ${constraints.maxWidth} x ${constraints.maxHeight}, '
          'item:$itemWidth x $itemHeight',
          tag: 'outside room audio video view',
          subTag: 'outside room audio video view',
        );

        return SingleChildScrollView(
          scrollDirection: widget.style.scrollDirection,
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: widget.style.backgroundColor.withOpacity(
                widget.style.backgroundColorOpacity,
              ),
              border: Border.all(
                color: widget.style.borderColor.withOpacity(
                  widget.style.borderColorOpacity,
                ),
              ),
              borderRadius: BorderRadius.all(
                Radius.circular(widget.style.borderRadius),
              ),
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: ValueListenableBuilder<
                  List<ZegoOutsideRoomAudioVideoViewStream>>(
                valueListenable: widget.controller.private.streamsNotifier,
                builder: (context, streams, _) {
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.style.scrollAxisCount,
                      childAspectRatio: widget.style.itemAspectRatio,
                    ),
                    scrollDirection: widget.style.scrollDirection,
                    itemCount: streams.length,
                    itemBuilder: (BuildContext context, int index) {
                      final stream = streams[index];
                      return VisibilityDetector(
                        key: Key(stream.targetStreamID),
                        onVisibilityChanged: (visibilityInfo) async {
                          stream.isVisibleNotifier.value =
                              visibilityInfo.visibleFraction > 0.1;
                        },
                        child: listItem(stream, itemWidth, itemHeight),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget listItem(
    ZegoOutsideRoomAudioVideoViewStream stream,
    double width,
    double height,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.style.item.borderColor.withOpacity(
            widget.style.item.borderColorOpacity,
          ),
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(widget.style.item.borderRadius),
        ),
      ),
      margin: widget.style.item.margin,
      child: StreamBuilder<List<ZegoUIKitUser>>(
        stream: ZegoUIKit().getAudioVideoListStream(),
        builder: (context, snapshot) {
          return Stack(
            children: [
              background(stream),
              videoView(stream),
              foreground(stream),
            ],
          );
        },
      ),
    );
  }

  Widget sdkInitWrapper({required Widget child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.sdkInitNotifier,
      builder: (context, isInit, _) {
        return isInit
            ? child
            : Center(
                child: widget.style.loadingBuilder?.call(context) ??
                    const CircularProgressIndicator(),
              );
      },
    );
  }

  Widget roomLoginWrapper({required Widget child}) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.roomLoginNotifier,
      builder: (context, isLogin, _) {
        return isLogin
            ? child
            : Center(
                child: widget.style.loadingBuilder?.call(context) ??
                    const CircularProgressIndicator(),
              );
      },
    );
  }

  Widget videoView(ZegoOutsideRoomAudioVideoViewStream stream) {
    return StreamBuilder<List<ZegoUIKitUser>>(
      stream: ZegoUIKit().getUserListStream(),
      builder: (context, snapshot) {
        final queryIndex = ZegoUIKit()
            .getAudioVideoList()
            .indexWhere((e) => e.id == stream.user.id);
        if (-1 == queryIndex) {
          return Center(
            child: widget.style.item.loadingBuilder?.call(
                  context,
                  stream.user,
                  stream.roomID,
                ) ??
                const CircularProgressIndicator(),
          );
        }

        return ZegoUIKit().getUser(stream.user.id).isEmpty()
            ? Center(
                child: widget.style.item.loadingBuilder?.call(
                      context,
                      stream.user,
                      stream.roomID,
                    ) ??
                    const CircularProgressIndicator(),
              )
            : ValueListenableBuilder<bool>(
                valueListenable:
                    ZegoUIKit().getCameraStateNotifier(stream.user.id),
                builder: (context, isCameraOn, _) {
                  if (!isCameraOn) {
                    ZegoLoggerService.logInfo(
                      '${stream.user.id}\'s camera is not open',
                      tag: 'uikit-component',
                      subTag: 'outside room audio video view',
                    );

                    return Container();
                  }

                  return SizedBox.expand(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ValueListenableBuilder<Widget?>(
                          valueListenable: ZegoUIKit()
                              .getAudioVideoViewNotifier(stream.user.id),
                          builder: (context, userView, _) {
                            if (userView == null) {
                              ZegoLoggerService.logError(
                                '${stream.user.id}\'s view is null',
                                tag: 'uikit-component',
                                subTag: 'outside room audio video view',
                              );

                              return Center(
                                child: widget.style.item.loadingBuilder?.call(
                                      context,
                                      stream.user,
                                      stream.roomID,
                                    ) ??
                                    const CircularProgressIndicator(),
                              );
                            }

                            ZegoLoggerService.logInfo(
                              'render ${stream.user.id}\'s view',
                              tag: 'uikit-component',
                              subTag: 'outside room audio video view',
                            );

                            return StreamBuilder(
                              stream: NativeDeviceOrientationCommunicator()
                                  .onOrientationChanged(),
                              builder: (context,
                                  AsyncSnapshot<NativeDeviceOrientation>
                                      asyncResult) {
                                if (asyncResult.hasData) {
                                  /// Do not update ui when ui is building !!!
                                  /// use postFrameCallback to update videoSize
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    ///  notify sdk to update video render orientation
                                    ZegoUIKit().updateAppOrientation(
                                      deviceOrientationMap(asyncResult.data!),
                                    );
                                  });
                                }

                                return userView;
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              );
      },
    );
  }

  Widget background(ZegoOutsideRoomAudioVideoViewStream stream) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: ZegoUIKitUserPropertiesNotifier(
                stream.user,
              ),
              builder: (context, _, __) {
                return widget.style.item.backgroundBuilder?.call(
                      context,
                      Size(constraints.maxWidth, constraints.maxHeight),
                      stream.user,
                      stream.roomID,
                    ) ??
                    Container(color: Colors.transparent);
              },
            ),
            avatar(stream, constraints.maxWidth, constraints.maxHeight),
          ],
        );
      },
    );
  }

  Widget foreground(ZegoOutsideRoomAudioVideoViewStream stream) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return widget.style.item.foregroundBuilder?.call(
              context,
              Size(constraints.maxWidth, constraints.maxHeight),
              stream.user,
              stream.roomID,
            ) ??
            Container(color: Colors.transparent);
      },
    );
  }

  Widget avatar(
    ZegoOutsideRoomAudioVideoViewStream stream,
    double maxWidth,
    double maxHeight,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallView = maxHeight < screenSize.height / 2;
    final avatarSize =
        isSmallView ? Size(110.zR, 110.zR) : Size(258.zR, 258.zR);

    var sizedWidth = widget.style.item.avatar?.size?.width ?? avatarSize.width;
    var sizedHeight =
        widget.style.item.avatar?.size?.height ?? avatarSize.width;
    if (sizedWidth > maxWidth) {
      sizedWidth = maxWidth;
    }
    if (sizedHeight > maxHeight) {
      sizedHeight = maxHeight;
    }

    final queryIndex = ZegoUIKit()
        .getAudioVideoList()
        .indexWhere((e) => e.id == stream.user.id);
    if (-1 == queryIndex) {
      return Container();
    }

    return Positioned(
      top: getAvatarTop(maxWidth, maxHeight, sizedHeight),
      left: (maxWidth - sizedWidth) / 2,
      child: SizedBox(
        width: sizedWidth,
        height: sizedHeight,
        child: ZegoAvatar(
          avatarSize: widget.style.item.avatar?.size ?? avatarSize,
          user: stream.user,
          showAvatar: widget.style.item.avatar?.showInAudioMode ?? true,
          showSoundLevel:
              widget.style.item.avatar?.showSoundWavesInAudioMode ?? true,
          avatarBuilder: widget.style.item.avatar?.builder,
          soundLevelSize: widget.style.item.avatar?.size,
          soundLevelColor: widget.style.item.avatar?.soundWaveColor,
        ),
      ),
    );
  }

  double getAvatarTop(double maxWidth, double maxHeight, double avatarHeight) {
    switch (widget.style.item.avatar?.verticalAlignment ??
        ZegoAvatarAlignment.center) {
      case ZegoAvatarAlignment.center:
        return (maxHeight - avatarHeight) / 2;
      case ZegoAvatarAlignment.start:
        return 15.zR; //  sound level height
      case ZegoAvatarAlignment.end:
        return maxHeight - avatarHeight;
    }
  }
}
