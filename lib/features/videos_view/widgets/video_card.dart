import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import '../../../service/FileStorageService.dart';
import '../pages/full_video_view.dart';

class VideoCard extends StatefulWidget {
  final File videoFile;
  final int index;

  const VideoCard({
    super.key,
    required this.videoFile,
    required this.index,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  Uint8List? _thumbnailBytes;
  bool _isLoadingThumbnail = true;
  final FileStorageService _fileService = FileStorageService.instance;
  BuildContext? _scaffoldContext;

  @override
  void initState() {
    super.initState();
    _loadVideoThumbnail();
  }

  Future<void> _loadVideoThumbnail() async {
    try {
      // Try to load pre-compressed video thumbnail from storage
      final videoFileName = p.basename(widget.videoFile.path);
      final thumbnailPath = await _fileService.getVideoThumbnailPath(videoFileName);

      if (thumbnailPath != null) {
        // Load the compressed video thumbnail
        final thumbnailBytes = await _fileService.readEncryptedFile(thumbnailPath);
        if (mounted && thumbnailBytes.isNotEmpty) {
          setState(() {
            _thumbnailBytes = Uint8List.fromList(thumbnailBytes);
            _isLoadingThumbnail = false;
          });
        }
      } else {
        // Fallback: generate thumbnail on the fly if no pre-compressed version exists
        await _generateThumbnailOnFly();
      }
    } catch (e) {
      print('Error loading video thumbnail: $e');
      // Fallback to on-the-fly generation
      await _generateThumbnailOnFly();
    }
  }

  Future<void> _generateThumbnailOnFly() async {
    try {
      // Decrypt the video file first
      final decryptedBytes = await _fileService.readEncryptedFile(widget.videoFile.path);

      // Create a temporary file for thumbnail generation
      final tempDir = Directory.systemTemp;
      final tempVideoFile = File('${tempDir.path}/temp_thumb_video_${widget.index}.mp4');
      await tempVideoFile.writeAsBytes(decryptedBytes);

      // Generate thumbnail from the decrypted video
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: tempVideoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
        timeMs: 1000, // Get thumbnail at 1 second
      );

      // Clean up temp file
      if (await tempVideoFile.exists()) {
        await tempVideoFile.delete();
      }

      if (mounted && thumbnailBytes != null) {
        setState(() {
          _thumbnailBytes = thumbnailBytes;
          _isLoadingThumbnail = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingThumbnail = false);
      }
    } catch (e) {
      print('Error generating video thumbnail on fly: $e');
      if (mounted) {
        setState(() => _isLoadingThumbnail = false);
      }
    }
  }

  void _showVideoOptionsDialog(BuildContext context, VideoViewProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Video Options'),
          content: const Text('Choose an action for this video.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                provider.deleteVideo(widget.index);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _restoreVideo(context, provider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreVideo(BuildContext context, VideoViewProvider provider) async {
    print('VideoCard: Starting video restore process');

    // Decrypt the video first
    final decryptedBytes = await _fileService.readEncryptedFile(widget.videoFile.path);
    print('VideoCard: Decrypted ${decryptedBytes.length} bytes');

    if (decryptedBytes.isEmpty) {
      print('VideoCard: No decrypted bytes, showing error snackbar');
      if (_scaffoldContext != null && mounted) {
        ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
          const SnackBar(content: Text('Failed to load video data')),
        );
      }
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
        if (_scaffoldContext != null && mounted) {
          ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
            const SnackBar(content: Text('Failed to access storage directory')),
          );
        }
        return;
      }

      print('Final save directory: ${saveDir.path}');
      print('Save location type: $saveLocation');

      // Create "file handler" subdirectory
      final fileHandlerDir = Directory(path.join(saveDir.path, 'file handler'));
      await fileHandlerDir.create(recursive: true);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = '.mp4'; // Assume mp4 for videos
      final fileName = 'restored_video_$timestamp$extension';
      final filePath = path.join(fileHandlerDir.path, fileName);

      // Write the decrypted bytes to the file
      final file = File(filePath);
      await file.writeAsBytes(decryptedBytes);
      print('File written to: $filePath');
      print('File exists after write: ${await file.exists()}');
      print('File size after write: ${await file.length()} bytes');

      // Delete from app
      provider.deleteVideo(widget.index);

      // Show success message with the actual save location
      String message;
      if (saveLocation == 'Download') {
        message = 'Successfully saved to Download/file handler folder: $fileName';
      } else {
        message = 'Successfully saved to app Documents/file handler folder: $fileName\n'
                 'Note: Enable "All files access" permission in settings for external storage';
      }

      if (_scaffoldContext != null && mounted) {
        ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error restoring video: $e');

      // If external storage failed, try fallback to app documents
      if (manageStorageStatus.isGranted && saveLocation == 'Download') {
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          if (fallbackDir != null) {
            final fileHandlerDir = Directory(path.join(fallbackDir.path, 'file handler'));
            await fileHandlerDir.create(recursive: true);

            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final extension = '.mp4';
            final fileName = 'restored_video_$timestamp$extension';
            final filePath = path.join(fileHandlerDir.path, fileName);

            final file = File(filePath);
            await file.writeAsBytes(decryptedBytes);

            provider.deleteVideo(widget.index);

            if (_scaffoldContext != null && mounted) {
              ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
                SnackBar(
                  content: const Text('Saved to app Documents/file handler folder\n'
                                   'Enable "All files access" permission for external storage'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        } catch (fallbackError) {
          print('Fallback save also failed: $fallbackError');
        }
      }

      if (_scaffoldContext != null && mounted) {
        ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
          const SnackBar(content: Text('Failed to restore video')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _scaffoldContext = context; // Store the scaffold context
    final provider = Provider.of<VideoViewProvider>(context);
    return GestureDetector(
      onTap: () {
        // Navigate to full video view
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullVideoViewScreen(
              videoFile: widget.videoFile,
              videoIndex: widget.index,
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
              child: _isLoadingThumbnail
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _thumbnailBytes != null
                      ? Image.memory(
                          _thumbnailBytes!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              child: const Icon(
                                Icons.video_file,
                                size: 50,
                                color: Color(0xFFF59E0B),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          child: const Icon(
                            Icons.video_file,
                            size: 50,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
            ),
            // Play button overlay
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 30,
              child: IconButton(
                onPressed: () => _showVideoOptionsDialog(context, provider),
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  shape: OvalBorder(),
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
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(
            //           path.basename(widget.videoFile.path),
            //           style: const TextStyle(
            //             color: Colors.white,
            //             fontSize: 10,
            //             fontWeight: FontWeight.w500,
            //           ),
            //           overflow: TextOverflow.ellipsis,
            //         ),
            //         Text(
            //           provider.getVideoSize(widget.videoFile),
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
