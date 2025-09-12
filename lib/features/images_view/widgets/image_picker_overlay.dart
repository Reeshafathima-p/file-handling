import 'package:flutter/material.dart';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';
import 'image_picker_bottom_sheet.dart';

class ImagePickerOverlay extends StatelessWidget {
  const ImagePickerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
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
                  onTap: () => provider.hideImagePicker(),
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
                child: const ImagePickerBottomSheet(),
              ),
            ),
          ],
        );
      },
    );
  }
}
