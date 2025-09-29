import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import 'video_card.dart';

class VideoGrid extends StatelessWidget {
  const VideoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: provider.selectedVideos.length,
      itemBuilder: (context, index) {
        return VideoCard(
          videoFile: provider.selectedVideos[index],
          index: index,
        );
      },
    );
  }
}
