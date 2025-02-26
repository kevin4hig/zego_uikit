// Dart imports:
import 'dart:async';
import 'dart:io' show Platform;

// Flutter imports:
import 'package:flutter/cupertino.dart';

// Package imports:
import 'package:zego_express_engine/zego_express_engine.dart';

// Project imports:
import 'package:zego_uikit/src/channel/platform_interface.dart';
import 'package:zego_uikit/src/services/internal/core/data/canvas_view_create_queue.dart';
import 'package:zego_uikit/src/services/internal/internal.dart';
import 'package:zego_uikit/src/services/services.dart';

class ZegoUIKitCoreDataStreamData {
  String userID;
  ZegoPlayerState playerState;
  ZegoPublisherState publisherState;

  ZegoUIKitCoreDataStreamData({
    required this.userID,
    this.playerState = ZegoPlayerState.NoPlay,
    this.publisherState = ZegoPublisherState.NoPublish,
  });

  @override
  String toString() {
    return 'user id:$userID, '
        'player state:$playerState, '
        'publisher state:$publisherState';
  }
}

mixin ZegoUIKitCoreDataStream {
  bool isEnablePlatformView = false;
  final canvasViewCreateQueue = ZegoStreamCanvasViewCreateQueue();
  bool isPlayingStream = false;
  bool isPublishingStream = false;
  bool isPreviewing = false;
  bool isEnableCustomVideoRender = false;
  Map<String, List<PlayerStateUpdateCallback>> playerStateUpdateCallbackList =
      {};

  bool get isCanvasViewCreateByQueue {
    if (Platform.isAndroid) {
      return false;
    }

    return isEnablePlatformView;
  }

  final Map<String, ZegoUIKitCoreMixerStream> mixerStreamDic =
      {}; // key:stream_id

  final Map<String, ZegoUIKitCoreDataStreamData> streamDic =
      {}; // stream_id:user_id

  ZegoAudioVideoResourceMode playResourceMode =
      ZegoAudioVideoResourceMode.defaultMode;

  bool isAllPlayStreamAudioVideoMuted = false;
  bool isAllPlayStreamAudioMuted = false;

  StreamController<List<ZegoUIKitCoreUser>>? audioVideoListStreamCtrl;
  StreamController<String>? turnOnYourCameraRequestStreamCtrl;
  StreamController<ZegoUIKitReceiveTurnOnLocalMicrophoneEvent>?
      turnOnYourMicrophoneRequestStreamCtrl;
  StreamController<ZegoUIKitReceiveSEIEvent>? receiveSEIStreamCtrl;

  ZegoUIKitVideoInternalConfig pushVideoConfig = ZegoUIKitVideoInternalConfig();

  void initStream() {
    ZegoLoggerService.logInfo(
      'init stream',
      tag: 'uikit-stream',
      subTag: 'init',
    );

    audioVideoListStreamCtrl ??=
        StreamController<List<ZegoUIKitCoreUser>>.broadcast();
    turnOnYourCameraRequestStreamCtrl ??= StreamController<String>.broadcast();
    turnOnYourMicrophoneRequestStreamCtrl ??= StreamController<
        ZegoUIKitReceiveTurnOnLocalMicrophoneEvent>.broadcast();
    receiveSEIStreamCtrl ??=
        StreamController<ZegoUIKitReceiveSEIEvent>.broadcast();
  }

  void uninitStream() {
    ZegoLoggerService.logInfo(
      'uninit stream',
      tag: 'uikit-stream',
      subTag: 'uninit',
    );

    isEnableCustomVideoRender = false;

    isEnablePlatformView = false;
    canvasViewCreateQueue.clear();

    audioVideoListStreamCtrl?.close();
    audioVideoListStreamCtrl = null;

    turnOnYourCameraRequestStreamCtrl?.close();
    turnOnYourCameraRequestStreamCtrl = null;

    turnOnYourMicrophoneRequestStreamCtrl?.close();
    turnOnYourMicrophoneRequestStreamCtrl = null;

    receiveSEIStreamCtrl?.close();
    receiveSEIStreamCtrl = null;

    isPreviewing = false;
    isPublishingStream = false;
    isPlayingStream = false;
  }

  String getLocalStreamID(ZegoStreamType streamType) {
    return getLocalStreamChannel(streamType).streamID;
  }

  ZegoUIKitCoreStreamInfo getLocalStreamChannel(ZegoStreamType streamType) {
    return getUserStreamChannel(
      ZegoUIKitCore.shared.coreData.localUser,
      streamType,
    );
  }

  ZegoUIKitCoreStreamInfo getUserStreamChannel(
    ZegoUIKitCoreUser user,
    ZegoStreamType streamType,
  ) {
    switch (streamType) {
      case ZegoStreamType.main:
        return user.mainChannel;
      case ZegoStreamType.media:
      case ZegoStreamType.screenSharing:
      case ZegoStreamType.mix:
        return user.auxChannel;
      // return user.thirdChannel;
    }
  }

  ZegoStreamType getStreamTypeByZegoPublishChannel(
    ZegoUIKitCoreUser user,
    ZegoPublishChannel channel,
  ) {
    switch (channel) {
      case ZegoPublishChannel.Main:
        return ZegoStreamType.main;
      case ZegoPublishChannel.Aux:
        return getStreamTypeByID(user.auxChannel.streamID);
      default:
        break;
    }

    assert(false);
    return ZegoStreamType.main;
  }

  ZegoStreamType getStreamTypeByID(String streamID) {
    if (streamID.endsWith(ZegoStreamType.main.text)) {
      return ZegoStreamType.main;
    } else if (streamID.endsWith(ZegoStreamType.media.text)) {
      return ZegoStreamType.media;
    } else if (streamID.endsWith(ZegoStreamType.screenSharing.text)) {
      return ZegoStreamType.screenSharing;
    } else if (streamID.endsWith(ZegoStreamType.mix.text)) {
      return ZegoStreamType.mix;
    }

    assert(false);
    return ZegoStreamType.main;
  }

  void clearStream() {
    ZegoLoggerService.logInfo(
      'clear stream',
      tag: 'uikit-stream',
      subTag: 'clearStream',
    );

    if (ZegoUIKitCore.shared.coreData.isScreenSharing.value) {
      ZegoUIKitCore.shared.coreData.stopSharingScreen();
    }

    for (final user in ZegoUIKitCore.shared.coreData.remoteUsersList) {
      if (user.mainChannel.streamID.isNotEmpty) {
        stopPlayingStream(user.mainChannel.streamID);
      }
      user.destroyTextureRenderer(streamType: ZegoStreamType.main);

      if (user.auxChannel.streamID.isNotEmpty) {
        stopPlayingStream(user.auxChannel.streamID);
      }
      user.destroyTextureRenderer(streamType: ZegoStreamType.screenSharing);
    }

    if (ZegoUIKitCore
        .shared.coreData.localUser.mainChannel.streamID.isNotEmpty) {
      stopPublishingStream(streamType: ZegoStreamType.main);
      ZegoUIKitCore.shared.coreData.localUser
          .destroyTextureRenderer(streamType: ZegoStreamType.main);
    }
    if (ZegoUIKitCore
        .shared.coreData.localUser.auxChannel.streamID.isNotEmpty) {
      stopPublishingStream(streamType: ZegoStreamType.screenSharing);
      ZegoUIKitCore.shared.coreData.localUser
          .destroyTextureRenderer(streamType: ZegoStreamType.screenSharing);
    }

    isPublishingStream = false;
    isPlayingStream = false;
  }

  Future<void> startPreview() async {
    ZegoLoggerService.logInfo(
      'start preview',
      tag: 'uikit-stream',
      subTag: 'start preview',
    );

    await createLocalUserVideoViewQueue(
      streamType: ZegoStreamType.main,
      onViewCreated: onViewCreatedByStartPreview,
    );
  }

  Future<void> onViewCreatedByStartPreview(ZegoStreamType streamType) async {
    ZegoLoggerService.logInfo(
      'start preview, on view created',
      tag: 'uikit-stream',
      subTag: 'onViewCreatedByStartPreview',
    );

    assert(ZegoUIKitCore.shared.coreData.localUser.mainChannel.viewID != -1);

    final previewCanvas = ZegoCanvas(
      ZegoUIKitCore.shared.coreData.localUser.mainChannel.viewID,
      viewMode: pushVideoConfig.useVideoViewAspectFill
          ? ZegoViewMode.AspectFill
          : ZegoViewMode.AspectFit,
    );

    ZegoExpressEngine.instance
      ..enableCamera(ZegoUIKitCore.shared.coreData.localUser.camera.value)
      ..startPreview(canvas: previewCanvas).then((_) {
        isPreviewing = true;
      });
  }

  Future<void> stopPreview() async {
    ZegoLoggerService.logInfo(
      'stop preview',
      tag: 'uikit-stream',
      subTag: 'stop preview',
    );

    await ZegoUIKitCore.shared.coreData.localUser
        .destroyTextureRenderer(streamType: ZegoStreamType.main);

    await ZegoExpressEngine.instance.stopPreview().then((_) {
      isPreviewing = false;
    });
  }

  Future<void> startPublishingStream({
    required ZegoStreamType streamType,
  }) async {
    final targetStreamID = getLocalStreamID(streamType);
    if (targetStreamID.isNotEmpty) {
      ZegoLoggerService.logWarn(
        'local user stream id($targetStreamID) of $streamType is not empty',
        tag: 'uikit-stream',
        subTag: 'start publish stream',
      );
      return;
    }

    getLocalStreamChannel(streamType)
      ..streamID = generateStreamID(
        ZegoUIKitCore.shared.coreData.localUser.id,
        ZegoUIKitCore.shared.coreData.room.id,
        streamType,
      )
      ..streamTimestamp =
          ZegoUIKitCore.shared.coreData.networkDateTime_.millisecondsSinceEpoch;
    streamDic[getLocalStreamChannel(streamType).streamID] =
        ZegoUIKitCoreDataStreamData(
      userID: ZegoUIKitCore.shared.coreData.localUser.id,
      publisherState: ZegoPublisherState.NoPublish,
    );

    ZegoLoggerService.logInfo(
      'stream dict add $streamType ${getLocalStreamChannel(streamType).streamID} for ${ZegoUIKitCore.shared.coreData.localUser.id}, '
      'now stream dict:$streamDic',
      tag: 'uikit-stream',
      subTag: 'start publish stream',
    );

    ZegoLoggerService.logInfo(
      'start publish, '
      '${getLocalStreamChannel(streamType).streamID}, '
      'network state:${ZegoUIKit().getNetworkState()}, ',
      tag: 'uikit-stream',
      subTag: 'start publish stream',
    );

    if (Platform.isIOS) {
      /// queue maybe stack without render(get view id) by start preview
      final localStreamChannel = getLocalStreamChannel(streamType);
      if (localStreamChannel.viewID == -1 &&
          localStreamChannel.view.value != null) {
        ZegoLoggerService.logInfo(
          'force update view to get view id on StartPreview',
          tag: 'uikit-stream',
          subTag: 'start publish stream',
        );

        /// force update, get view id
        notifyStreamListControl(streamType);
      }
    }

    await createLocalUserVideoViewQueue(
      streamType: streamType,
      onViewCreated: onViewCreatedByStartPublishingStream,
    );
  }

  Future<void> onViewCreatedByStartPublishingStream(
    ZegoStreamType streamType,
  ) async {
    /// advance config
    switch (streamType) {
      case ZegoStreamType.main:
        assert(getLocalStreamChannel(streamType).viewID != -1);
        final canvas = ZegoCanvas(
          getLocalStreamChannel(streamType).viewID,
          viewMode: pushVideoConfig.useVideoViewAspectFill
              ? ZegoViewMode.AspectFill
              : ZegoViewMode.AspectFit,
        );

        await ZegoExpressEngine.instance
            .enableCamera(ZegoUIKitCore.shared.coreData.localUser.camera.value);
        await ZegoExpressEngine.instance.muteMicrophone(
          !ZegoUIKitCore.shared.coreData.localUser.microphone.value,
        );
        await ZegoExpressEngine.instance.startPreview(canvas: canvas).then((_) {
          isPreviewing = true;
        });
        break;
      case ZegoStreamType.media:
        await ZegoExpressEngine.instance.setVideoSource(
          ZegoVideoSourceType.Player,
          instanceID:
              ZegoUIKitCore.shared.coreData.media.currentPlayer!.getIndex(),
          channel: streamType.channel,
        );
        await ZegoExpressEngine.instance.setAudioSource(
          ZegoAudioSourceType.MediaPlayer,
          channel: streamType.channel,
        );

        await ZegoExpressEngine.instance.setVideoConfig(
          ZegoUIKitCore.shared.coreData.media.getPreferVideoConfig(),
          channel: streamType.channel,
        );

        final canvas = ZegoCanvas(
          ZegoUIKitCore.shared.coreData
              .getLocalStreamChannel(streamType)
              .viewID,
          viewMode: ZegoViewMode.AspectFit,
        );
        ZegoUIKitCore.shared.coreData.media.currentPlayer!
            .setPlayerCanvas(canvas);
        break;
      case ZegoStreamType.screenSharing:
        await ZegoExpressEngine.instance.setVideoSource(
          ZegoVideoSourceType.ScreenCapture,
          instanceID:
              ZegoUIKitCore.shared.coreData.screenCaptureSource!.getIndex(),
          channel: streamType.channel,
        );
        await ZegoExpressEngine.instance.setAudioSource(
          ZegoAudioSourceType.ScreenCapture,
          channel: streamType.channel,
        );

        await ZegoExpressEngine.instance.setVideoConfig(
          ZegoVideoConfig.preset(ZegoVideoConfigPreset.Preset540P),
          channel: streamType.channel,
        );

        break;
      case ZegoStreamType.mix:
        await ZegoExpressEngine.instance.setVideoConfig(
          ZegoVideoConfig.preset(ZegoVideoConfigPreset.Preset540P),
          channel: streamType.channel,
        );
        break;
    }

    await ZegoExpressEngine.instance
        .startPublishingStream(
      getLocalStreamID(streamType),
      channel: streamType.channel,
    )
        .then((_) {
      isPublishingStream = true;
    });

    notifyStreamListControl(streamType);
  }

  Future<void> stopPublishingStream({
    required ZegoStreamType streamType,
  }) async {
    final targetStreamID = getLocalStreamID(streamType);
    ZegoLoggerService.logInfo(
      'stop $streamType $targetStreamID}, '
      'network state:${ZegoUIKit().getNetworkState()}, ',
      tag: 'uikit-stream',
      subTag: 'stop publish stream',
    );

    if (targetStreamID.isEmpty) {
      ZegoLoggerService.logInfo(
        'stream id is empty',
        tag: 'uikit-stream',
        subTag: 'stop publish stream',
      );

      return;
    }

    streamDic.remove(targetStreamID);
    ZegoLoggerService.logInfo(
      'stream dict remove $targetStreamID, now stream dict:$streamDic',
      tag: 'uikit-stream',
      subTag: 'stop publish stream',
    );

    getLocalStreamChannel(streamType)
      ..streamID = ''
      ..streamTimestamp = 0;

    ZegoUIKitCore.shared.coreData.localUser
        .destroyTextureRenderer(streamType: streamType);

    switch (streamType) {
      case ZegoStreamType.main:
        await ZegoExpressEngine.instance.stopPreview().then((_) {
          isPreviewing = false;
        });
        break;
      case ZegoStreamType.media:
        await ZegoExpressEngine.instance.setVideoSource(
          ZegoVideoSourceType.None,
          channel: streamType.channel,
        );
        await ZegoExpressEngine.instance.setAudioSource(
          ZegoAudioSourceType.Default,
          channel: streamType.channel,
        );
        break;
      case ZegoStreamType.screenSharing:
        await ZegoExpressEngine.instance.setVideoSource(
          ZegoVideoSourceType.None,
          channel: streamType.channel,
        );
        await ZegoExpressEngine.instance.setAudioSource(
          ZegoAudioSourceType.Default,
          channel: streamType.channel,
        );
        break;
      default:
        break;
    }

    await ZegoExpressEngine.instance
        .stopPublishingStream(channel: streamType.channel)
        .then((value) {
      isPublishingStream = false;

      audioVideoListStreamCtrl?.add(getAudioVideoList());
      ZegoUIKitCore.shared.coreData.screenSharingListStreamCtrl
          ?.add(getAudioVideoList(streamType: ZegoStreamType.screenSharing));
      ZegoUIKitCore.shared.coreData.media.mediaListStreamCtrl
          ?.add(getAudioVideoList(streamType: ZegoStreamType.media));
    });
  }

  Future<void> startPublishOrNot() async {
    if (ZegoUIKitCore.shared.coreData.room.id.isEmpty) {
      ZegoLoggerService.logWarn(
        'room id is empty',
        tag: 'uikit-stream',
        subTag: 'publish stream',
      );
      return;
    }

    if (ZegoUIKitCore.shared.coreData.localUser.camera.value ||
        ZegoUIKitCore.shared.coreData.localUser.cameraMuteMode.value ||
        ZegoUIKitCore.shared.coreData.localUser.microphone.value ||
        ZegoUIKitCore.shared.coreData.localUser.microphoneMuteMode.value) {
      startPublishingStream(
        streamType: ZegoStreamType.main,
      );
    } else {
      if (ZegoUIKitCore
          .shared.coreData.localUser.mainChannel.streamID.isNotEmpty) {
        stopPublishingStream(
          streamType: ZegoStreamType.main,
        );
      }
    }
  }

  Future<Widget?> createCanvasViewByExpressWithCompleter(
    Function(int viewID) onViewCreated, {
    Key? key,
  }) async {
    Key? canvasViewKey;
    if (Platform.isIOS && isEnablePlatformView) {
      /// iOS & platform view, express view id not callback sometimes, or call random
      canvasViewKey = key;
    }

    ZegoLoggerService.logInfo(
      'with express with key:$canvasViewKey',
      tag: 'uikit-stream',
      subTag: 'create canvas view',
    );

    return await ZegoExpressEngine.instance.createCanvasView(
      (int viewID) async {
        if (isCanvasViewCreateByQueue) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onViewCreated.call(viewID);

            canvasViewCreateQueue.completeCurrentTask();
          });
        } else {
          onViewCreated.call(viewID);
        }
      },
      key: canvasViewKey,
    );
  }

  Future<void> createLocalUserVideoViewQueue({
    required ZegoStreamType streamType,
    required void Function(ZegoStreamType) onViewCreated,
  }) async {
    if (isCanvasViewCreateByQueue) {
      final localStreamChannel = getLocalStreamChannel(streamType);
      if (localStreamChannel.viewID != -1 &&
          localStreamChannel.view.value != null) {
        await createLocalUserVideoView(
          streamType: streamType,
          onViewCreated: onViewCreated,
        );
      } else {
        ZegoLoggerService.logInfo(
          'add to queue',
          tag: 'uikit-stream',
          subTag: 'create local user video view',
        );

        canvasViewCreateQueue.addTask(() async {
          await createLocalUserVideoView(
            streamType: streamType,
            onViewCreated: onViewCreated,
          );
        });
      }
    } else {
      await createLocalUserVideoView(
        streamType: streamType,
        onViewCreated: onViewCreated,
      );
    }
  }

  Future<void> createLocalUserVideoView({
    required ZegoStreamType streamType,
    required void Function(ZegoStreamType) onViewCreated,
  }) async {
    final localStreamChannel = getLocalStreamChannel(streamType);
    ZegoLoggerService.logInfo(
      'current streamChannel, '
      'view id:${localStreamChannel.viewID},'
      'view:${localStreamChannel.view}',
      tag: 'uikit-stream',
      subTag: 'create local user video view',
    );

    if (localStreamChannel.viewID != -1 &&
        localStreamChannel.view.value != null) {
      ZegoLoggerService.logInfo(
        'user view had created, directly call callback, '
        'view id:${localStreamChannel.viewID},'
        'view:${localStreamChannel.view}',
        tag: 'uikit-stream',
        subTag: 'create local user video view',
      );

      if (isCanvasViewCreateByQueue) {
        canvasViewCreateQueue.completeCurrentTask();
      }

      onViewCreated(streamType);
    } else {
      await createCanvasViewByExpressWithCompleter(
        (viewID) async {
          ZegoLoggerService.logInfo(
            'view id done, viewID:$viewID',
            tag: 'uikit-stream',
            subTag: 'create local user video view',
          );

          localStreamChannel.viewID = viewID;

          onViewCreated(streamType);
        },
        key: localStreamChannel.globalKey.value,
      ).then((widget) {
        ZegoLoggerService.logInfo(
          'widget done, widget:$widget ${widget.hashCode}',
          tag: 'uikit-stream',
          subTag: 'create local user video view',
        );

        localStreamChannel.view.value = widget;

        notifyStreamListControl(streamType);
      });
    }
  }

  Future<bool> mutePlayStreamAudioVideo(
    String userID,
    bool mute, {
    bool forAudio = true,
    bool forVideo = true,
  }) async {
    ZegoLoggerService.logInfo(
      'userID: $userID, mute: $mute, '
      'for audio:$forAudio, for video:$forVideo',
      tag: 'uikit-stream',
      subTag: 'mute play stream audio video',
    );

    final targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => userID == user.id);
    if (-1 == targetUserIndex) {
      ZegoLoggerService.logError(
        "can't find $userID",
        tag: 'uikit-stream',
        subTag: 'mute play stream audio video',
      );
      return false;
    }

    final targetUser =
        ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex];
    if (targetUser.mainChannel.streamID.isEmpty) {
      ZegoLoggerService.logError(
        "can't find $userID's stream",
        tag: 'uikit-stream',
        subTag: 'mute play stream audio video',
      );
      return false;
    }

    if (forAudio) {
      targetUser.microphoneMuteMode.value = mute;
      await ZegoExpressEngine.instance.mutePlayStreamAudio(
        targetUser.mainChannel.streamID,
        mute,
      );
    }

    if (forVideo) {
      targetUser.cameraMuteMode.value = mute;
      await ZegoExpressEngine.instance.mutePlayStreamVideo(
        targetUser.mainChannel.streamID,
        mute,
      );
    }

    return true;
  }

  Future<void> muteAllPlayStreamAudioVideo(bool isMuted) async {
    ZegoLoggerService.logInfo(
      'muted: $isMuted, streamDic:$streamDic',
      tag: 'uikit-stream',
      subTag: 'mute all play stream audio video',
    );

    isAllPlayStreamAudioVideoMuted = isMuted;
    await ZegoExpressEngine.instance
        .muteAllPlayStreamVideo(isAllPlayStreamAudioVideoMuted);
    await ZegoExpressEngine.instance
        .muteAllPlayStreamAudio(isAllPlayStreamAudioVideoMuted);

    streamDic.forEach((streamID, streamInfo) async {
      if (isMuted) {
        if (ZegoPlayerState.Playing == streamInfo.playerState) {
          await stopPlayingStream(streamID, removeDic: false);
        } else {
          ZegoLoggerService.logInfo(
            'stream id($streamID) not playing(${streamInfo.playerState}) now, waiting player state update',
            tag: 'uikit-stream',
            subTag: 'mute all play stream audio video',
          );
        }
      } else {
        if (ZegoUIKitCore.shared.coreData.localUser.id != streamInfo.userID &&
            streamInfo.playerState == ZegoPlayerState.NoPlay) {
          await startPlayingStreamQueue(streamID, streamInfo.userID);
        }
      }
    });
  }

  Future<void> muteAllPlayStreamAudio(bool isMuted) async {
    ZegoLoggerService.logInfo(
      'muted: $isMuted, streamDic:$streamDic',
      tag: 'uikit-stream',
      subTag: 'mute all play stream audio',
    );

    isAllPlayStreamAudioMuted = isMuted;
    await ZegoExpressEngine.instance
        .muteAllPlayStreamAudio(isAllPlayStreamAudioMuted);
  }

  Future<void> startPlayingStreamQueue(
    String streamID,
    String streamUserID,
  ) async {
    if (isCanvasViewCreateByQueue) {
      final targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
          .indexWhere((user) => streamUserID == user.id);
      final targetUser =
          ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex];
      final streamType = getStreamTypeByID(streamID);

      final targetUserStreamChannel =
          getUserStreamChannel(targetUser, streamType);
      if (targetUserStreamChannel.viewID != -1 &&
          targetUserStreamChannel.view.value != null) {
        await startPlayingStream(streamID, streamUserID);
      } else {
        ZegoLoggerService.logInfo(
          'add to queue',
          tag: 'uikit-stream',
          subTag: 'start play stream',
        );

        canvasViewCreateQueue.addTask(
          () async {
            await startPlayingStream(streamID, streamUserID);
          },
        );
      }
    } else {
      await startPlayingStream(streamID, streamUserID);
    }
  }

  /// will change data variables
  Future<void> startPlayingStream(
    String streamID,
    String streamUserID,
  ) async {
    ZegoLoggerService.logInfo(
      'stream id: $streamID, user id:$streamUserID',
      tag: 'uikit-stream',
      subTag: 'start play stream',
    );

    final targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => streamUserID == user.id);
    assert(-1 != targetUserIndex);
    final targetUser =
        ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex];
    final streamType = getStreamTypeByID(streamID);

    getUserStreamChannel(targetUser, streamType)
      ..streamID = streamID
      ..streamTimestamp =
          ZegoUIKitCore.shared.coreData.networkDateTime_.millisecondsSinceEpoch;

    final targetUserStreamChannel =
        getUserStreamChannel(targetUser, streamType);
    ZegoLoggerService.logInfo(
      'current stream channel, '
      'view id:${targetUserStreamChannel.viewID},'
      'view:${targetUserStreamChannel.view}',
      tag: 'uikit-stream',
      subTag: 'start play stream',
    );
    if (targetUserStreamChannel.viewID != -1 &&
        targetUserStreamChannel.view.value != null) {
      final viewID = getUserStreamChannel(targetUser, streamType).viewID;

      ZegoLoggerService.logInfo(
        'canvas view had created before, directly call callback, '
        'viewID:$viewID, '
        'user id:$streamUserID, '
        'stream id:$streamID, ',
        tag: 'uikit-stream',
        subTag: 'start play stream',
      );

      if (isCanvasViewCreateByQueue) {
        canvasViewCreateQueue.completeCurrentTask();
      }

      playStreamOnViewCreated(
        streamID: streamID,
        streamUserID: streamUserID,
        viewID: viewID,
        streamType: streamType,
      );
    } else {
      await createCanvasViewByExpressWithCompleter(
        (viewID) async {
          ZegoLoggerService.logInfo(
            'canvas view id done '
            'viewID:$viewID, '
            'user id:$streamUserID, '
            'stream id:$streamID, ',
            tag: 'uikit-stream',
            subTag: 'start play stream',
          );

          getUserStreamChannel(targetUser, streamType).viewID = viewID;

          playStreamOnViewCreated(
            streamID: streamID,
            streamUserID: streamUserID,
            viewID: viewID,
            streamType: streamType,
          );
        },
        key: targetUserStreamChannel.globalKey.value,
      ).then((widget) {
        ZegoLoggerService.logInfo(
          'widget done, '
          'widget:$widget ${widget.hashCode}, '
          'user id:$streamUserID, '
          'stream id:$streamID, ',
          tag: 'uikit-stream',
          subTag: 'start play stream',
        );

        getUserStreamChannel(targetUser, streamType).view.value = widget;

        notifyStreamListControl(streamType);
      });
    }
  }

  Future<void> startPlayingStreamByExpress({
    required int viewID,
    required String streamID,
    ZegoCanvas? canvas,
    ZegoPlayerConfig? config,
    PlayerStateUpdateCallback? onPlayerStateUpdated,
  }) async {
    bool startPlayingStreamInIOSPIP = false;
    if (Platform.isIOS) {
      startPlayingStreamInIOSPIP =
          ZegoUIKitCore.shared.playingStreamInPIPUnderIOS;
    }

    ZegoLoggerService.logInfo(
      'viewID:$viewID, '
      'streamID:$streamID, '
      'startPlayingStreamInIOSPIP:$startPlayingStreamInIOSPIP, ',
      tag: 'uikit-stream',
      subTag: 'start play stream by express',
    );

    if (null != onPlayerStateUpdated) {
      if (playerStateUpdateCallbackList.containsKey(streamID)) {
        playerStateUpdateCallbackList[streamID]!.add(onPlayerStateUpdated);
      } else {
        playerStateUpdateCallbackList[streamID] = [onPlayerStateUpdated];
      }
    }

    if (startPlayingStreamInIOSPIP) {
      ZegoUIKitPluginPlatform.instance
          .startPlayingStreamInPIP(
        viewID,
        streamID,
      )
          .then((_) {
        isPlayingStream = true;

        ZegoLoggerService.logInfo(
          'finish play stream in ios with pip, '
          'stream id: $streamID, ',
          tag: 'uikit-stream',
          subTag: 'start play stream',
        );
      });
    } else {
      await ZegoExpressEngine.instance
          .startPlayingStream(
        streamID,
        canvas: canvas,
        config: config,
      )
          .then((value) {
        isPlayingStream = true;

        ZegoLoggerService.logInfo(
          'finish play, '
          'stream id: $streamID, ',
          tag: 'uikit-stream',
          subTag: 'start play stream',
        );
      });
    }
  }

  Future<void> stopPlayingStreamByExpress(String streamID) async {
    bool stopPlayingStreamInIOSPIP = false;
    if (Platform.isIOS) {
      stopPlayingStreamInIOSPIP =
          ZegoUIKitCore.shared.playingStreamInPIPUnderIOS;
    }

    ZegoLoggerService.logInfo(
      'streamID:$streamID, '
      'stopPlayingStreamInIOSPIP:$stopPlayingStreamInIOSPIP, ',
      tag: 'uikit-stream',
      subTag: 'stop play stream by express',
    );

    if (stopPlayingStreamInIOSPIP) {
      ZegoUIKitPluginPlatform.instance
          .stopPlayingStreamInPIP(streamID)
          .then((_) {
        ZegoLoggerService.logInfo(
          'stop play done in ios with pip, '
          'stream id: $streamID, ',
          tag: 'uikit-stream',
          subTag: 'stop play stream',
        );
      });
    } else {
      await ZegoExpressEngine.instance.stopPlayingStream(streamID).then((_) {
        ZegoLoggerService.logInfo(
          'stop play done, '
          'stream id: $streamID, ',
          tag: 'uikit-stream',
          subTag: 'stop play stream',
        );
      });
    }
  }

  void playStreamOnViewCreated({
    required String streamID,
    required String streamUserID,
    required int viewID,
    required ZegoStreamType streamType,
  }) async {
    final canvas = ZegoCanvas(
      viewID,
      viewMode: ZegoStreamType.main == streamType
          ? (pushVideoConfig.useVideoViewAspectFill
              ? ZegoViewMode.AspectFill
              : ZegoViewMode.AspectFit)

          /// screen share/media default AspectFit
          : ZegoViewMode.AspectFit,
    );
    final playConfig = ZegoPlayerConfig(
      ZegoUIKitCore.shared.coreData.playResourceMode.toSdkValue,
    );

    ZegoLoggerService.logInfo(
      'ready start, stream id: $streamID, user id:$streamUserID',
      tag: 'uikit-stream',
      subTag: 'start play stream',
    );

    await startPlayingStreamByExpress(
      viewID: viewID,
      streamID: streamID,
      canvas: canvas,
      config: playConfig,
    );
  }

  void notifyStreamListControl(ZegoStreamType streamType) {
    switch (streamType) {
      case ZegoStreamType.main:
        audioVideoListStreamCtrl?.add(getAudioVideoList());
        break;
      case ZegoStreamType.media:
        ZegoUIKitCore.shared.coreData.media.mediaListStreamCtrl
            ?.add(getAudioVideoList(streamType: streamType));
        break;
      case ZegoStreamType.screenSharing:
        ZegoUIKitCore.shared.coreData.screenSharingListStreamCtrl
            ?.add(getAudioVideoList(streamType: streamType));
        break;
      case ZegoStreamType.mix:
        break;
    }
  }

  /// will change data variables
  Future<void> stopPlayingStream(
    String streamID, {
    bool removeDic = true,
  }) async {
    ZegoLoggerService.logInfo(
      'ready stop stream id: $streamID',
      tag: 'uikit-stream',
      subTag: 'stop play stream',
    );
    assert(streamID.isNotEmpty);

    // stop playing stream
    await stopPlayingStreamByExpress(streamID);

    final targetUserID =
        streamDic.containsKey(streamID) ? streamDic[streamID]!.userID : '';
    ZegoLoggerService.logInfo(
      'stopped, stream id $streamID, user id  is: $targetUserID',
      tag: 'uikit-stream',
      subTag: 'stop play stream',
    );
    final targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => targetUserID == user.id);
    if (-1 != targetUserIndex) {
      final targetUser =
          ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex];

      final streamType = getStreamTypeByID(streamID);
      getUserStreamChannel(targetUser, streamType)
        ..streamID = ''
        ..streamTimestamp = 0;
      targetUser.destroyTextureRenderer(streamType: streamType);
      if (streamType == ZegoStreamType.main) {
        targetUser
          ..camera.value = false
          ..cameraMuteMode.value = false
          ..microphone.value = false
          ..microphoneMuteMode.value = false;
      }

      notifyStreamListControl(streamType);
    }

    if (removeDic) {
      // clear streamID
      streamDic.remove(streamID);
      ZegoLoggerService.logInfo(
        'stream dict remove $streamID, $streamDic',
        tag: 'uikit-stream',
        subTag: 'stop play stream',
      );
    }
  }

  List<ZegoUIKitCoreUser> getAudioVideoList({
    ZegoStreamType streamType = ZegoStreamType.main,
  }) {
    return ZegoUIKitCore.shared.coreData.streamDic.entries
        .where((value) => value.key.endsWith(streamType.text))
        .map((entry) {
      final targetUserID = entry.value.userID;
      if (targetUserID == ZegoUIKitCore.shared.coreData.localUser.id) {
        return ZegoUIKitCore.shared.coreData.localUser;
      }
      return ZegoUIKitCore.shared.coreData.remoteUsersList.firstWhere(
          (user) => targetUserID == user.id,
          orElse: ZegoUIKitCoreUser.empty);
    }).where((user) {
      if (user.id.isEmpty) {
        return false;
      }

      if (streamType == ZegoStreamType.main) {
        /// if camera is in mute mode, same as open state
        final isCameraOpen = user.camera.value || user.cameraMuteMode.value;

        /// if microphone is in mute mode, same as open state
        final isMicrophoneOpen =
            user.microphone.value || user.microphoneMuteMode.value;

        /// only open camera or microphone
        return isCameraOpen || isMicrophoneOpen;
      }

      return true;
    }).toList();
  }

  Future<void> startPlayAnotherRoomAudioVideo(
    String roomID,
    String userID,
    String userName, {
    PlayerStateUpdateCallback? onPlayerStateUpdated,
  }) async {
    var targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => userID == user.id);
    final isUserExist = -1 != targetUserIndex;
    if (!isUserExist) {
      ZegoUIKitCore.shared.coreData.remoteUsersList
          .add(ZegoUIKitCoreUser(userID, userName)..isAnotherRoomUser = true);

      ZegoLoggerService.logInfo(
        'add $userID, now remote list:${ZegoUIKitCore.shared.coreData.remoteUsersList}',
        tag: 'uikit-stream',
        subTag: 'start play another room stream',
      );
    }
    targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => userID == user.id);

    final streamID = generateStreamID(userID, roomID, ZegoStreamType.main);
    streamDic[streamID] = ZegoUIKitCoreDataStreamData(
      userID: userID,
      playerState: ZegoPlayerState.NoPlay,
    );
    ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex]
      ..mainChannel.streamID = streamID
      ..mainChannel.streamTimestamp =
          ZegoUIKitCore.shared.coreData.networkDateTime_.millisecondsSinceEpoch;

    ZegoLoggerService.logInfo(
      'roomID:$roomID, '
      'userID:$userID, userName:$userName, '
      'streamID:$streamID, '
      'targetUserIndex:$targetUserIndex, ',
      tag: 'uikit-stream',
      subTag: 'start play another room stream',
    );

    await ZegoExpressEngine.instance.createCanvasView((viewID) async {
      var targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
          .indexWhere((user) => userID == user.id);

      if (-1 == targetUserIndex) {
        ZegoLoggerService.logInfo(
          'createCanvasView onViewCreated, '
          'but user can not find now! '
          'userID:$userID, targetUserIndex:$targetUserIndex, ',
          tag: 'uikit-stream',
          subTag: 'start play another room stream',
        );

        return;
      }

      ZegoLoggerService.logInfo(
        'createCanvasView onViewCreated, '
        'viewID:$viewID, '
        'remote user list:${ZegoUIKitCore.shared.coreData.remoteUsersList}, '
        'userID:$userID, userName:$userName, targetUserIndex:$targetUserIndex, ',
        tag: 'uikit-stream',
        subTag: 'start play another room stream',
      );

      ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex].mainChannel
          .viewID = viewID;
      final canvas = ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);

      final playConfig = ZegoPlayerConfig(
        ZegoUIKitCore.shared.coreData.playResourceMode.toSdkValue,
      );
      await startPlayingStreamByExpress(
        viewID: viewID,
        streamID: streamID,
        canvas: canvas,
        config: playConfig,
        onPlayerStateUpdated: onPlayerStateUpdated,
      );
    }).then((widget) {
      var targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
          .indexWhere((user) => userID == user.id);

      if (-1 == targetUserIndex) {
        ZegoLoggerService.logInfo(
          'createCanvasView done, '
          'but user can not find now! '
          'userID:$userID, targetUserIndex:$targetUserIndex, ',
          tag: 'uikit-stream',
          subTag: 'start play another room stream',
        );

        return;
      }

      ZegoLoggerService.logInfo(
        'createCanvasView done, '
        'widget:$widget, '
        'roomID:$roomID, '
        'userID:$userID, userName:$userName, targetUserIndex:$targetUserIndex, '
        'streamID:$streamID, ',
        tag: 'uikit-stream',
        subTag: 'start play another room stream',
      );

      assert(widget != null);
      ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex].mainChannel
          .view.value = widget;

      notifyStreamListControl(ZegoStreamType.main);
      if (!isUserExist) {
        ZegoUIKitCore.shared.coreData.notifyUserListStreamControl();
      }
    });
  }

  Future<void> stopPlayAnotherRoomAudioVideo(String userID) async {
    ZegoLoggerService.logInfo(
      'userID:$userID',
      tag: 'uikit-stream',
      subTag: 'stop play another room stream',
    );

    final targetUserIndex = ZegoUIKitCore.shared.coreData.remoteUsersList
        .indexWhere((user) => userID == user.id);
    if (-1 == targetUserIndex) {
      ZegoLoggerService.logWarn(
        "can't find this user, userID:$userID",
        tag: 'uikit-stream',
        subTag: 'stop play another room stream',
      );

      return;
    }

    final targetUser =
        ZegoUIKitCore.shared.coreData.remoteUsersList[targetUserIndex];

    final streamID = ZegoUIKitCore
        .shared.coreData.remoteUsersList[targetUserIndex].mainChannel.streamID;
    await stopPlayingStreamByExpress(streamID);

    targetUser
      ..mainChannel.streamID = ''
      ..mainChannel.streamTimestamp = 0
      ..destroyTextureRenderer(streamType: ZegoStreamType.main)
      ..camera.value = false
      ..cameraMuteMode.value = false
      ..microphone.value = false
      ..microphoneMuteMode.value = false
      ..mainChannel.soundLevel?.add(0);

    streamDic.remove(streamID);
    ZegoUIKitCore.shared.coreData.remoteUsersList
        .removeWhere((user) => userID == user.id);
    ZegoLoggerService.logInfo(
      'stopped, userID:$userID, streamID:$streamID',
      tag: 'uikit-stream',
      subTag: 'stop play another room stream',
    );

    notifyStreamListControl(ZegoStreamType.main);
    ZegoUIKitCore.shared.coreData.notifyUserListStreamControl();
  }

  Future<void> startPlayMixAudioVideo(
    String mixerID,
    List<ZegoUIKitCoreUser> users,
    Map<String, int> userSoundIDs, {
    PlayerStateUpdateCallback? onPlayerStateUpdated,
  }) async {
    ZegoLoggerService.logInfo(
      'mixerID:$mixerID, users:$users, userSoundIDs:$userSoundIDs',
      tag: 'uikit-mixstream',
      subTag: 'start play mix audio video',
    );

    if (mixerStreamDic.containsKey(mixerID)) {
      for (var user in users) {
        if (-1 ==
            mixerStreamDic[mixerID]!
                .usersNotifier
                .value
                .indexWhere((e) => e.id == user.id)) {
          mixerStreamDic[mixerID]!.addUser(user);
        }
      }
      mixerStreamDic[mixerID]!.userSoundIDs.addAll(userSoundIDs);
    } else {
      mixerStreamDic[mixerID] = ZegoUIKitCoreMixerStream(
        mixerID,
        userSoundIDs,
        users,
      );

      ZegoExpressEngine.instance.createCanvasView((viewID) async {
        mixerStreamDic[mixerID]!.viewID = viewID;
        final canvas = ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);

        final playConfig = ZegoPlayerConfig(
          ZegoUIKitCore.shared.coreData.playResourceMode.toSdkValue,
        );

        startPlayingStreamByExpress(
          viewID: viewID,
          streamID: mixerID,
          canvas: canvas,
          config: playConfig,
          onPlayerStateUpdated: onPlayerStateUpdated,
        );

        Future.delayed(const Duration(seconds: 3), () {
          mixerStreamDic[mixerID]?.loaded.value = true;
        });
      }).then((widget) {
        assert(widget != null);
        mixerStreamDic[mixerID]!.view.value = widget;

        notifyStreamListControl(ZegoStreamType.main);
      });
    }
  }

  Future<void> stopPlayMixAudioVideo(String mixerID) async {
    ZegoLoggerService.logInfo(
      'mixerID:$mixerID',
      tag: 'uikit-mixstream',
      subTag: 'stop play mix audio video',
    );

    stopPlayingStreamByExpress(mixerID);

    mixerStreamDic[mixerID]?.destroyTextureRenderer();
    mixerStreamDic.remove(mixerID);
  }
}
