import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import 'loading_state.dart';
import 'empty_state.dart';
import 'video_grid.dart';

class ContentArea extends StatelessWidget {
  const ContentArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);

    if (provider.isLoading && provider.selectedVideos.isEmpty) {
      return const LoadingState();
    } else if (provider.selectedVideos.isEmpty) {
      return const EmptyState();
    } else {
      return VideoGrid();
    }
  }
}
