import 'dart:io';
import 'FileStorageService.dart';

class StatsService {
  StatsService._();
  static final instance = StatsService._();

  final FileStorageService _fileService = FileStorageService.instance;

  Future<Map<String, dynamic>> getFileStats() async {
    try {
      // Get all file lists
      final images = await _fileService.listImages();
      final audio = await _fileService.listAudio();
      final videos = await _fileService.listVideo();
      final other = await _fileService.listOther();

      // Calculate counts
      final imageCount = images.length;
      final audioCount = audio.length;
      final videoCount = videos.length;
      final otherCount = other.length;
      final totalFiles = imageCount + audioCount + videoCount + otherCount;

      // Calculate storage usage
      int totalSize = 0;

      // Helper function to calculate size of file list
      int calculateSize(List<File> files) {
        return files.fold(0, (sum, file) {
          try {
            return sum + file.lengthSync();
          } catch (e) {
            return sum; // Skip files that can't be read
          }
        });
      }

      totalSize += calculateSize(images);
      totalSize += calculateSize(audio);
      totalSize += calculateSize(videos);
      totalSize += calculateSize(other);

      // Also include thumbnails in storage calculation
      final thumbnails = await _fileService.listThumbnails();
      totalSize += calculateSize(thumbnails);

      // Format storage size
      String formatSize(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }

      return {
        'totalFiles': totalFiles,
        'images': imageCount,
        'audio': audioCount,
        'videos': videoCount,
        'other': otherCount,
        'storageUsed': formatSize(totalSize),
        'storageUsedBytes': totalSize,
      };
    } catch (e) {
      // Return default values on error
      return {
        'totalFiles': 0,
        'images': 0,
        'audio': 0,
        'videos': 0,
        'other': 0,
        'storageUsed': '0 B',
        'storageUsedBytes': 0,
        'error': e.toString(),
      };
    }
  }
}
