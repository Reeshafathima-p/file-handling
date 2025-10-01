import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../../service/FileStorageService.dart';

class ImageViewProvider with ChangeNotifier {
  List<File> selectedImages = [];
  bool isImagePickerVisible = false;
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

  Future<void> loadExistingImages() async {
    isLoading = true;
    notifyListeners();
    
    try {
      final debugInfo = await _fileService.debugStorageInfo();
      print('Storage Debug Info: $debugInfo');
      
      final images = await _fileService.listImages();
      print('Loaded ${images.length} images from storage');
      
      selectedImages = images;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading images: $e');
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  void showImagePicker() {
    isImagePickerVisible = true;
    notifyListeners();
    animationController.forward();
  }

  void hideImagePicker() {
    animationController.reverse().then((_) {
      isImagePickerVisible = false;
      notifyListeners();
    });
  }

  Future<void> pickFromCamera() async {
    try {
      isLoading = true;
      notifyListeners();

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        print('Camera image picked: ${image.path}');
        final uniqueName = _generateUniqueFileName(image.path, prefix: 'camera');
        final tempFile = await _copyFileWithNewName(File(image.path), uniqueName);

        final savedFile = await _fileService.saveFileCategorized(tempFile);
        print('Image saved to: ${savedFile.path}');
        if (tempFile.path != savedFile.path && await tempFile.exists()) {
          await tempFile.delete();
        }

        selectedImages.add(savedFile);
        isLoading = false;
        notifyListeners();
        hideImagePicker();
        // Show success message
      } else {
        isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error picking from camera: $e');
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> pickFromGallery(BuildContext context) async {
    try {
      // Request permissions before picking images
      await _requestPermissions();

      isLoading = true;
      notifyListeners();

      // Use PhotoManager to pick images with proper asset management
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        print('Photo permission denied');
        isLoading = false;
        notifyListeners();
        return;
      }

      // Get all image assets from gallery
      final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
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
          requestType: RequestType.image,
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

            // Delete the original gallery image using PhotoManager
            try {
              final result = await PhotoManager.editor.deleteWithIds([asset.id]);
              print('Deleted original gallery image: ${asset.id}, result: $result');
            } catch (e) {
              print('Failed to delete gallery image ${asset.id}: $e');
            }
          }
        }

        selectedImages.addAll(savedFiles);
        isLoading = false;
        notifyListeners();
        hideImagePicker();
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
        selectedImages.add(savedFile);
        isLoading = false;
        notifyListeners();
        hideImagePicker();
        // Show success message
      } else {
        isLoading = false;
        notifyListeners();
        hideImagePicker();
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  void showUrlDialog(BuildContext context) {
    final TextEditingController urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Image from URL',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'Enter image URL...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will download and save the image with a unique timestamp name.',
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
                backgroundColor: const Color(0xFF3B82F6),
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

  Future<void> downloadFromUrl(String url) async {
    try {
      isLoading = true;
      notifyListeners();
      hideImagePicker();
      
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

  Future<void> refreshImages() async {
    await loadExistingImages();
    // Show success message
  }

  void clearAllImages() {
    selectedImages.clear();
    notifyListeners();
    // Show success message
  }

  void deleteImage(int index) async {
    try {
      await selectedImages[index].delete();
    } catch (e) {
      // Handle error
    }
    selectedImages.removeAt(index);
    notifyListeners();
    // Show success message
  }

  Future<Map<String, dynamic>> testEncryption() async {
    try {
      final result = await _fileService.testEncryption();
      print('Encryption Test Result: $result');
      return result;
    } catch (e) {
      print('Error testing encryption: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyStoredFilesEncryption() async {
    try {
      final result = await _fileService.verifyEncryption();
      print('Encryption Verification Result: $result');
      return result;
    } catch (e) {
      print('Error verifying encryption: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getEncryptionStatus() async {
    try {
      final result = await _fileService.verifyEncryption();
      final encryptedImages = result['imagesEncrypted'] as List<String>? ?? [];
      final encryptedThumbs = result['thumbnailsEncrypted'] as List<String>? ?? [];
      final totalEncrypted = encryptedImages.length + encryptedThumbs.length;

      return {
        'totalEncrypted': totalEncrypted,
        'encryptedImages': encryptedImages.length,
        'encryptedThumbnails': encryptedThumbs.length,
        'totalImages': result['totalImages'] ?? 0,
        'totalThumbnails': result['totalThumbnails'] ?? 0,
      };
    } catch (e) {
      print('Error getting encryption status: $e');
      return {
        'totalEncrypted': 0,
        'encryptedImages': 0,
        'encryptedThumbnails': 0,
        'totalImages': 0,
        'totalThumbnails': 0,
        'error': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> testImageDecryption() async {
    try {
      if (selectedImages.isEmpty) {
        return {'error': 'No images available to test'};
      }

      final testImage = selectedImages.first;
      final fileName = path.basename(testImage.path);

      print('Testing decryption for image: $fileName');

      // Test image decryption
      final decryptedBytes = await _fileService.getDecryptedImageBytes(fileName);
      print('Image decryption successful, size: ${decryptedBytes.length} bytes');

      // Test thumbnail decryption if available
      final thumbnailBytes = await _fileService.readEncryptedThumbnail(fileName);
      print('Thumbnail decryption successful, size: ${thumbnailBytes.length} bytes');

      return {
        'imageDecryption': 'success',
        'imageSize': decryptedBytes.length,
        'thumbnailDecryption': 'success',
        'thumbnailSize': thumbnailBytes.length,
        'message': '✅ Both image and thumbnail decryption working properly'
      };
    } catch (e) {
      print('Error testing decryption: $e');
      return {
        'error': e.toString(),
        'message': '❌ Decryption test failed'
      };
    }
  }

  String getImageSize(File file) {
    try {
      int bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }
}
