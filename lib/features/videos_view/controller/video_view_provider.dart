import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../../service/FileStorageService.dart';

class VideoViewProvider with ChangeNotifier {
  List<File> selectedVideos = [];
  bool isVideoPickerVisible = false;
  bool isLoading = false;
  late AnimationController animationController;
  late Animation<double> scaleAnimation;
  late Animation<double> opacityAnimation;
  final ImagePicker _picker = ImagePicker();
  final FileStorageService _fileService = FileStorageService.instance;

  void setAnimationController(AnimationController controller) {
    animationController = controller;
    scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.elasticOut),
    );
    opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeIn),
    );
  }

  void dispose() {
    animationController.dispose();
  }

  String _generateUniqueFileName(String originalPath, {String? prefix}) {
    final extension = path.extension(originalPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dateTime = DateTime.now();
    final formattedDate = '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';

    if (prefix != null) {
      return '${prefix}_${formattedDate}_$timestamp$extension';
    }
    return '${formattedDate}_$timestamp$extension';
  }


  Future<File> _copyFileWithNewName(File sourceFile, String newFileName) async {
    final directory = sourceFile.parent;
    final newPath = path.join(directory.path, newFileName);
    return await sourceFile.copy(newPath);
  }

  Future<void> _requestPermissions() async {
    try {
      final storageStatus = await Permission.storage.request();
      final photosStatus = await Permission.photos.request();
      final manageStorageStatus = await Permission.manageExternalStorage.request();
      final photoManagerStatus = await PhotoManager.requestPermissionExtend();

      print('Storage permission: $storageStatus');
      print('Photos permission: $photosStatus');
      print('Manage external storage permission: $manageStorageStatus');
      print('Photo manager permission: $photoManagerStatus');

      if (storageStatus.isDenied || photosStatus.isDenied || manageStorageStatus.isDenied || !photoManagerStatus.isAuth) {
        // Handle permission denied
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> loadExistingVideos() async {
    isLoading = true;
    notifyListeners();

    try {
      final debugInfo = await _fileService.debugStorageInfo();
      print('Storage Debug Info: $debugInfo');

      final videos = await _fileService.listVideo();
      print('Loaded ${videos.length} videos from storage');

      selectedVideos = videos;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading videos: $e');
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  void showVideoPicker() {
    isVideoPickerVisible = true;
    notifyListeners();
    animationController.forward();
  }

  void hideVideoPicker() {
    animationController.reverse().then((_) {
      isVideoPickerVisible = false;
      notifyListeners();
    });
  }

  Future<void> pickFromCamera() async {
    try {
      isLoading = true;
      notifyListeners();

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        print('Camera video picked: ${video.path}');
        final uniqueName = _generateUniqueFileName(video.path, prefix: 'camera');
        final tempFile = await _copyFileWithNewName(File(video.path), uniqueName);

        final savedFile = await _fileService.saveFileCategorized(tempFile);
        print('Video saved to: ${savedFile.path}');
        if (tempFile.path != savedFile.path && await tempFile.exists()) {
          await tempFile.delete();
        }

        selectedVideos.add(savedFile);
        isLoading = false;
        notifyListeners();
        hideVideoPicker();
        // Show success message
      } else {
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> pickFromGallery(BuildContext context) async {
    try {
      // Request permissions before picking videos
      await _requestPermissions();

      isLoading = true;
      notifyListeners();

      // Use PhotoManager to pick videos with proper asset management
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        print('Photo permission denied');
        isLoading = false;
        notifyListeners();
        return;
      }

      // Get all video assets from gallery
      final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      if (albums.isEmpty) {
        print('No albums found');
        isLoading = false;
        notifyListeners();
        return;
      }

      // Use the first album (usually "Recent" or "All")
      final album = albums.first;
      final assets = await album.getAssetListPaged(page: 0, size: 100);

      // Use wechat_assets_picker for proper asset selection with deletion capability
      final List<AssetEntity>? selectedAssets = await AssetPicker.pickAssets(
        context, // Need to get context somehow
        pickerConfig: const AssetPickerConfig(
          maxAssets: 10,
          requestType: RequestType.video,
          selectedAssets: [],
        ),
      );

      if (selectedAssets != null && selectedAssets.isNotEmpty) {
        List<File> savedFiles = [];

        for (final asset in selectedAssets) {
          // Get the file from the asset
          final file = await asset.file;
          if (file != null) {
            final uniqueName = _generateUniqueFileName(file.path, prefix: 'gallery');
            final tempFile = await _copyFileWithNewName(file, uniqueName);

            final savedFile = await _fileService.saveFileCategorized(tempFile);

            savedFiles.add(savedFile);

            if (tempFile.path != savedFile.path && await tempFile.exists()) {
              await tempFile.delete();
            }

            // Delete the original gallery video using PhotoManager
            try {
              final result = await PhotoManager.editor.deleteWithIds([asset.id]);
              print('Deleted original gallery video: ${asset.id}, result: $result');
            } catch (e) {
              print('Failed to delete gallery video ${asset.id}: $e');
            }
          }
        }

        selectedVideos.addAll(savedFiles);
        isLoading = false;
        notifyListeners();
        hideVideoPicker();
        // Show success message
      } else {
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error in pickFromGallery: $e');
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> pickFromFiles() async {
    try {
      isLoading = true;
      notifyListeners();
      // Delete original file from storage after saving to app
      final File? savedFile = await _fileService.pickAndSaveCategorized(deleteOriginal: true);

      if (savedFile != null) {
        selectedVideos.add(savedFile);
        isLoading = false;
        notifyListeners();
        hideVideoPicker();
        // Show success message
      } else {
        isLoading = false;
        notifyListeners();
        hideVideoPicker();
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> downloadFromUrl(String url) async {
    try {
      isLoading = true;
      notifyListeners();
      hideVideoPicker();

      await Future.delayed(const Duration(seconds: 1));

      isLoading = false;
      notifyListeners();
      // Show success message

    } catch (e) {
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> refreshVideos() async {
    await loadExistingVideos();
    // Show success message
  }

  void clearAllVideos() {
    selectedVideos.clear();
    notifyListeners();
    // Show success message
  }

  void deleteVideo(int index) async {
    try {
      await selectedVideos[index].delete();
    } catch (e) {
      // Handle error
    }
    selectedVideos.removeAt(index);
    notifyListeners();
    // Show success message
  }

  void showUrlDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Video from URL',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'Enter video URL...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will download and save the video with a unique timestamp name.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (urlController.text.isNotEmpty) {
                  Navigator.pop(context);
                  await downloadFromUrl(urlController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Download', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String getVideoSize(File file) {
    try {
      int bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown';
    }
  }
}
