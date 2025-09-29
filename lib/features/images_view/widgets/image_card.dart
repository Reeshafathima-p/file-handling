import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

  void _showImageOptionsDialog(BuildContext context, ImageViewProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Image Options'),
          content: const Text('Choose an action for this image.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                provider.deleteImage(widget.index);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _restoreImage(context, provider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreImage(BuildContext context, ImageViewProvider provider) async {
    if (_decryptedBytes == null || _decryptedBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load image data')),
      );
      return;
    }

    // Check if we have manage external storage permission
    PermissionStatus manageStorageStatus = await Permission.manageExternalStorage.status;
    print('MANAGE_EXTERNAL_STORAGE permission status: $manageStorageStatus');

    // If not granted, request it
    if (!manageStorageStatus.isGranted) {
      manageStorageStatus = await Permission.manageExternalStorage.request();
      print('After requesting: MANAGE_EXTERNAL_STORAGE permission status: $manageStorageStatus');
    }

    Directory? saveDir;
    String saveLocation = 'internal storage';

    try {
      if (manageStorageStatus.isGranted) {
        // With MANAGE_EXTERNAL_STORAGE permission, use the real Downloads directory
        // On Android, this is /storage/emulated/0/Download (note the capitalization)
        saveDir = Directory('/storage/emulated/0/Download');
        print('Using real Downloads directory: ${saveDir.path}');

        // Verify the directory exists or can be created
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }

        saveLocation = 'Download';
      }

      // Fallback to app documents directory if external storage not available or not permitted
      if (saveDir == null || !await saveDir.exists()) {
        saveDir = await getApplicationDocumentsDirectory();
        print('App Documents directory: ${saveDir?.path}');
        saveLocation = 'app Documents';
      }

      if (saveDir == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access storage directory')),
        );
        return;
      }

      print('Final save directory: ${saveDir.path}');
      print('Save location type: $saveLocation');

      // Create "file handler" subdirectory
      final fileHandlerDir = Directory(path.join(saveDir.path, 'file handler'));
      await fileHandlerDir.create(recursive: true);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getImageExtension(_decryptedBytes!);
      final fileName = 'restored_image_$timestamp$extension';
      final filePath = path.join(fileHandlerDir.path, fileName);

      // Write the decrypted bytes to the file
      final file = File(filePath);
      await file.writeAsBytes(_decryptedBytes!);
      print('File written to: $filePath');
      print('File exists after write: ${await file.exists()}');
      print('File size after write: ${await file.length()} bytes');

      // Delete from app
      provider.deleteImage(widget.index);

      // Show success message with the actual save location
      String message;
      if (saveLocation == 'Downloads') {
        message = 'Successfully saved to download/file handler folder: $fileName';
      } else {
        message = 'Successfully saved to app Documents/file handler folder: $fileName';
                //  'Note: Enable "All files access" permission in settings for external storage';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('Error restoring image: $e');

      // If external storage failed, try fallback to app documents
      if (manageStorageStatus.isGranted && saveLocation == 'Downloads') {
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          if (fallbackDir != null) {
            final fileHandlerDir = Directory(path.join(fallbackDir.path, 'file handler'));
            await fileHandlerDir.create(recursive: true);

            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final extension = _getImageExtension(_decryptedBytes!);
            final fileName = 'restored_image_$timestamp$extension';
            final filePath = path.join(fileHandlerDir.path, fileName);

            final file = File(filePath);
            await file.writeAsBytes(_decryptedBytes!);

            provider.deleteImage(widget.index);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Saved to app Documents/file handler folder\n'
                                 'Enable "All files access" permission for external storage'),
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
        } catch (fallbackError) {
          print('Fallback save also failed: $fallbackError');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to restore image')),
      );
    }
  }

  String _getImageExtension(List<int> bytes) {
    if (bytes.length < 4) return '.jpg';

    final header = bytes.sublist(0, 4);
    if (header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8) {
      return '.jpg'; // JPEG
    } else if (header.length >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
      return '.png'; // PNG
    } else if (header.length >= 4 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) {
      return '.gif'; // GIF
    }
    return '.jpg'; // Default
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
              top: 0,
              left: 30,
              child: IconButton(
                onPressed: () => _showImageOptionsDialog(context, provider),
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 20,
                  
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  // shape: const CircleBorder(),
                  shape: OvalBorder()
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
            //         // Expanded(
            //         //   child: Text(
            //         //     path.basename(imageFile.path),
            //         //     style: const TextStyle(
            //         //       color: Colors.white,
            //         //       fontSize: 10,
            //         //       fontWeight: FontWeight.w500,
            //         //     ),
            //         //     overflow: TextOverflow.ellipsis,
            //         //   ),
            //         // ),
            //         // Text(
            //         //   provider.getImageSize(imageFile),
            //         //   style: const TextStyle(
            //         //     color: Colors.white70,
            //         //     fontSize: 10,
            //         //   ),
            //         // ),
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
