import 'package:flutter/material.dart';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Managed Files",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          provider.selectedImages.isEmpty
            ? "Files are automatically organized with unique timestamp names"
            : "${provider.selectedImages.length} file${provider.selectedImages.length > 1 ? 's' : ''} in images folder",
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
