import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';
import '../../../service/FileStorageService.dart';
import '../pages/full_image_view.dart';


class ImageCard extends StatefulWidget {
  final File imageFile;
  final int index;

  const ImageCard({
    super.key,
    required this.imageFile,
    required this.index,
  });

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  List<int>? _decryptedBytes;
  bool _isLoading = true;
  final FileStorageService _fileService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    _loadDecryptedImage();
  }

  Future<void> _loadDecryptedImage() async {
    try {
      final imageFileName = path.basename(widget.imageFile.path);
      print('ImageCard: Image filename: $imageFileName');
      print('ImageCard: Full image file path: ${widget.imageFile.path}');
      print('ImageCard: File exists: ${await widget.imageFile.exists()}');
      print('ImageCard: File size: ${await widget.imageFile.length()} bytes');

      // Try to load thumbnail first for better performance
      try {
        _decryptedBytes = await _fileService.readEncryptedThumbnail(imageFileName);
        print('ImageCard: Successfully loaded thumbnail, size: ${_decryptedBytes?.length ?? 0} bytes');
      } catch (e) {
        print('ImageCard: Thumbnail not available, falling back to full image: $e');
        // Fallback to full image if thumbnail fails
        _decryptedBytes = await _fileService.readEncryptedFile(widget.imageFile.path);
        print('ImageCard: Successfully loaded full image, size: ${_decryptedBytes?.length ?? 0} bytes');
      }
      print('ImageCard: Successfully decrypted image, size: ${_decryptedBytes?.length ?? 0} bytes');
      if (_decryptedBytes != null && _decryptedBytes!.isNotEmpty) {
        print('ImageCard: First 10 bytes of decrypted data: ${_decryptedBytes!.sublist(0, _decryptedBytes!.length > 10 ? 10 : _decryptedBytes!.length)}');

        // Validate that decrypted data looks like image data
        if (_decryptedBytes!.length > 4) {
          final header = _decryptedBytes!.sublist(0, 4);
          print('ImageCard: Image header bytes: $header');

          // Check for common image signatures
          bool isValidImage = false;
          if (header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8) {
            isValidImage = true; // JPEG
            print('ImageCard: Detected JPEG format');
          } else if (header.length >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
            isValidImage = true; // PNG
            print('ImageCard: Detected PNG format');
          } else if (header.length >= 4 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) {
            isValidImage = true; // GIF
            print('ImageCard: Detected GIF format');
          }

          if (!isValidImage) {
            print('ImageCard: WARNING - Decrypted data does not appear to be valid image data!');
            print('ImageCard: Checking if file is actually encrypted...');

            // Check if the original file contains valid image data (not encrypted)
            final rawBytes = await widget.imageFile.readAsBytes();
            if (rawBytes.length > 4) {
              final rawHeader = rawBytes.sublist(0, 4);
              print('ImageCard: Raw file header: $rawHeader');
              if ((rawHeader.length >= 2 && rawHeader[0] == 0xFF && rawHeader[1] == 0xD8) ||
                  (rawHeader.length >= 4 && rawHeader[0] == 0x89 && rawHeader[1] == 0x50 && rawHeader[2] == 0x4E && rawHeader[3] == 0x47) ||
                  (rawHeader.length >= 4 && rawHeader[0] == 0x47 && rawHeader[1] == 0x49 && rawHeader[2] == 0x46 && rawHeader[3] == 0x38)) {
                print('ImageCard: File appears to be unencrypted! Using raw bytes instead.');
                _decryptedBytes = rawBytes;
              } else {
                _decryptedBytes = null; // Set to null so error state is shown
              }
            } else {
              _decryptedBytes = null;
            }
          }
        }
      } else {
        print('ImageCard: Decrypted bytes is null or empty');
      }
    } catch (e) {
      print('ImageCard: Error decrypting image: $e');
      print('ImageCard: Image file path: ${widget.imageFile.path}');
      _decryptedBytes = null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
    return GestureDetector(
      onTap: () {
        // Navigate to full image view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullImageViewScreen(
              imageFile: widget.imageFile,
              imageIndex: widget.index,
            ),
          ),
        );
      },
      child: Container(
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
              child: _isLoading
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _decryptedBytes != null
                      ? Builder(
                          builder: (context) {
                            try {
                              final uint8List = Uint8List.fromList(_decryptedBytes!);
                              print('ImageCard: Created Uint8List with ${uint8List.length} bytes');
                              return Image.memory(
                                uint8List,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('ImageCard: Image.memory error: $error');
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
                              );
                            } catch (e) {
                              print('ImageCard: Error creating Uint8List: $e');
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
                            }
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          child: const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Color(0xFFEF4444),
                          ),
                        ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => provider.deleteImage(widget.index),
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
            //             path.basename(imageFile.path),
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
      ),
    );
  }
}
