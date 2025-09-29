import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Managed Videos",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          provider.selectedVideos.isEmpty
            ? "Videos are automatically organized with unique timestamp names"
            : "${provider.selectedVideos.length} video${provider.selectedVideos.length > 1 ? 's' : ''} in videos folder",
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
