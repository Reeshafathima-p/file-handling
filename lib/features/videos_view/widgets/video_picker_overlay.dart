import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import 'video_picker_bottom_sheet.dart';

class VideoPickerOverlay extends StatelessWidget {
  const VideoPickerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);
    return AnimatedBuilder(
      animation: provider.animationController,
      builder: (context, child) {
        return Stack(
          children: [
            Opacity(
              opacity: provider.opacityAnimation.value * 0.5,
              child: Container(
                color: Colors.black,
                child: GestureDetector(
                  onTap: () => provider.hideVideoPicker(),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.scale(
                scale: provider.scaleAnimation.value,
                alignment: Alignment.bottomCenter,
                child: const VideoPickerBottomSheet(),
              ),
            ),
          ],
        );
      },
    );
  }
}
