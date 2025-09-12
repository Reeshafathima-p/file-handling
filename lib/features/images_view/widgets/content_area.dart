import 'package:flutter/material.dart';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';
import 'loading_state.dart';
import 'empty_state.dart';
import 'image_grid.dart';

class ContentArea extends StatelessWidget {
  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
    
    if (provider.isLoading && provider.selectedImages.isEmpty) {
      return const LoadingState();
    } else if (provider.selectedImages.isEmpty) {
      return const EmptyState();
    } else {
      return ImageGrid();
    }
  }
}
