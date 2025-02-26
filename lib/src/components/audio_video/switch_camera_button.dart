// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Project imports:
import 'package:zego_uikit/src/components/defines.dart';
import 'package:zego_uikit/src/components/internal/internal.dart';
import 'package:zego_uikit/src/components/screen_util/screen_util.dart';
import 'package:zego_uikit/src/services/services.dart';

/// switch cameras
class ZegoSwitchCameraButton extends StatefulWidget {
  const ZegoSwitchCameraButton({
    Key? key,
    this.onPressed,
    this.icon,
    this.defaultUseFrontFacingCamera = true,
    this.iconSize,
    this.buttonSize,
  }) : super(key: key);

  final ButtonIcon? icon;

  ///  You can do what you want after pressed.
  final void Function(bool isFrontFacing)? onPressed;

  /// whether to use the front-facing camera by default
  final bool defaultUseFrontFacingCamera;

  /// the size of button's icon
  final Size? iconSize;

  /// the size of button
  final Size? buttonSize;

  @override
  State<ZegoSwitchCameraButton> createState() => _ZegoSwitchCameraButtonState();
}

class _ZegoSwitchCameraButtonState extends State<ZegoSwitchCameraButton> {
  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      /// synchronizing the default status
      ZegoUIKit().useFrontFacingCamera(widget.defaultUseFrontFacingCamera);
    });
  }

  @override
  Widget build(BuildContext context) {
    final containerSize = widget.buttonSize ?? Size(96.zR, 96.zR);
    final sizeBoxSize = widget.iconSize ?? Size(56.zR, 56.zR);

    return ValueListenableBuilder<bool>(
      valueListenable: ZegoUIKit()
          .getUseFrontFacingCameraStateNotifier(ZegoUIKit().getLocalUser().id),
      builder: (context, isFrontFacing, _) {
        return GestureDetector(
          onTap: () async {
            final targetState = !isFrontFacing;
            await ZegoUIKit().useFrontFacingCamera(targetState);

            if (widget.onPressed != null) {
              widget.onPressed!(targetState);
            }
          },
          child: Container(
            width: containerSize.width,
            height: containerSize.height,
            decoration: BoxDecoration(
              color: widget.icon?.backgroundColor ??
                  controlBarButtonCheckedBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: SizedBox.fromSize(
              size: sizeBoxSize,
              child: widget.icon?.icon ??
                  UIKitImage.asset(StyleIconUrls.iconS1ControlBarFlipCamera),
            ),
          ),
        );
      },
    );
  }
}
