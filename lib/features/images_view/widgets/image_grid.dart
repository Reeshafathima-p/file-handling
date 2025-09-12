import 'package:flutter/material.dart';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';
import 'image_card.dart';

class ImageGrid extends StatelessWidget {
  const ImageGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: provider.selectedImages.length,
      itemBuilder: (context, index) {
        return ImageCard(
          imageFile: provider.selectedImages[index],
          index: index,
        );
      },
    );
  }
}
