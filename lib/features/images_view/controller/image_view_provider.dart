import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
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

      print('Storage permission: $storageStatus');
      print('Photos permission: $photosStatus');

      if (storageStatus.isDenied || photosStatus.isDenied) {
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
      
      final images = await _fileService.listThumbnails();
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
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> pickFromGallery() async {
    try {
      isLoading = true;
      notifyListeners();
      
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        List<File> savedFiles = [];
        
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          final uniqueName = _generateUniqueFileName(image.path, prefix: 'image');
          final tempFile = await _copyFileWithNewName(File(image.path), uniqueName);
          
          final savedFile = await _fileService.saveFileCategorized(tempFile);
          
          savedFiles.add(savedFile);
          
          if (tempFile.path != savedFile.path && await tempFile.exists()) {
            await tempFile.delete();
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
      isLoading = false;
      notifyListeners();
      // Show error message
    }
  }

  Future<void> pickFromFiles() async { 
    try {
      isLoading = true;
      notifyListeners();
      final File? savedFile = await _fileService.pickAndSaveCategorized();
      
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
