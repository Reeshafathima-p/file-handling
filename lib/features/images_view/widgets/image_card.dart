import 'package:flutter/material.dart';
import 'dart:io';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';

class ImageCard extends StatelessWidget {
  final File imageFile;
  final int index;

  const ImageCard({
    super.key,
    required this.imageFile,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              imageFile,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  child: const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Color(0xFFEF4444),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => provider.deleteImage(index),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          // Positioned(
          //   bottom: 8,
          //   left: 8,
          //   right: 8,
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //     decoration: BoxDecoration(
          //       color: Colors.black.withOpacity(0.7),
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //       children: [
          //         Expanded(
          //           child: Text(
          //             imageFile.path.split('/').last,
          //             style: const TextStyle(
          //               color: Colors.white,
          //               fontSize: 10,
          //               fontWeight: FontWeight.w500,
          //             ),
          //             overflow: TextOverflow.ellipsis,
          //           ),
          //         ),
          //         Text(
          //           provider.getImageSize(imageFile),
          //           style: const TextStyle(
          //             color: Colors.white70,
          //             fontSize: 10,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
