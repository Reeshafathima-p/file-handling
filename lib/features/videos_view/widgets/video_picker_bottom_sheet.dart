import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import 'picker_option.dart';

class VideoPickerBottomSheet extends StatelessWidget {
  const VideoPickerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Add Video",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Videos will be automatically organized with unique names",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: PickerOption(
                  icon: Icons.videocam_rounded,
                  label: "Camera",
                  color: const Color(0xFF10B981),
                  onTap: () => provider.pickFromCamera(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PickerOption(
                  icon: Icons.video_library_rounded,
                  label: "Gallery",
                  color: const Color(0xFF3B82F6),
                  onTap: () => provider.pickFromGallery(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PickerOption(
                  icon: Icons.folder_rounded,
                  label: "Files",
                  color: const Color(0xFFF59E0B),
                  onTap: () => provider.pickFromFiles(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PickerOption(
                  icon: Icons.link_rounded,
                  label: "URL",
                  color: const Color(0xFFEC4899),
                  onTap: () => provider.showUrlDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => provider.hideVideoPicker(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
