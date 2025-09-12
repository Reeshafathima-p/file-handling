import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FileStorageService {
  FileStorageService._();
  static final instance = FileStorageService._();

  // Root: app documents directory
  Future<Directory> _docsDir() => getApplicationDocumentsDirectory(); // [13]

  // Resolve a subfolder under docs (images, audio, video, other)
  Future<Directory> _ensureSubdir(String name) async {
    final docs = await _docsDir();
    final dir = Directory(p.join(docs.path, name));
    return dir.create(recursive: true);
  }

  // Decide subfolder by MIME type
  String _folderForMime(String? mime, {String fallback = 'other'}) {
    if (mime == null) return fallback;
    if (mime.startsWith('image/')) return 'images';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('video/')) return 'video';
    return 'other';
  }

  // Detect MIME from path and, if needed, header bytes.
  Future<String?> _detectMime(String path) async {
    // Try by extension first
    var mime = lookupMimeType(path); // e.g., image/png, audio/mpeg, video/mp4 [6]
    if (mime != null) return mime;
    // Fallback to magic bytes (handles wrong/absent extensions) [6]
    try {
      final file = File(path);
      if (await file.exists()) {
        // Read up to 512 bytes (enough for most magic numbers)
        final raf = await file.open();
        final len = await raf.length();
        final n = len > 512 ? 512 : len;
        final bytes = await raf.read(n);
        await raf.close();
        mime = lookupMimeType(path, headerBytes: bytes); // [6]
      }
    } catch (_) {
      // ignore errors -> null mime
    }
    return mime;
  }
  

  // Compute destination directory name by MIME type
  Future<String> _dirNameForPath(String srcPath) async {
    final mime = await _detectMime(srcPath); // [6]
    return _folderForMime(mime);
  }

  // Create thumbnail for image files using flutter_image_compress for maximum compression
  Future<void> _createThumbnail(File sourceFile, String originalFileName) async {
    try {
      final mime = await _detectMime(sourceFile.path);
      if (mime == null || !mime.startsWith('image/')) {
        return; // Not an image, skip thumbnail creation
      }

      // Get original file size for comparison
      final originalBytes = await sourceFile.readAsBytes();
      final originalSize = originalBytes.length;

      // Create thumbnails directory
      final thumbnailsDir = await _ensureSubdir('thumbnails');

      // Generate thumbnail filename: thumb_[original_filename]
      final nameWithoutExt = p.basenameWithoutExtension(originalFileName);
      final thumbnailFileName = 'thumb_$nameWithoutExt.jpg';
      final thumbnailPath = p.join(thumbnailsDir.path, thumbnailFileName);

      // Use flutter_image_compress for maximum compression with resized dimensions
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        sourceFile.absolute.path,
        quality: 5, 
        // format: CompressFormat.jpeg, // Use WebP for better compression
        // minWidth: 100, // Resize to 100px width for thumbnail
        // minHeight: 100, // Resize to 100px height for thumbnail
        keepExif: false, // Remove EXIF data to reduce size
        autoCorrectionAngle: false, // Skip auto rotation to save processing
      );

      if (compressedBytes == null) {
        print('Failed to compress image: ${sourceFile.path}');
        return;
      }

      // Save compressed thumbnail
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(compressedBytes);

      final compressedSize = compressedBytes.length;
      final compressionRatio = ((originalSize - compressedSize) / originalSize * 100).round();

      print('Thumbnail created with maximum compression: $thumbnailPath');
      print('Original size: ${originalSize} bytes, Compressed size: ${compressedSize} bytes');
      print('Compression ratio: ${compressionRatio}% size reduction');
    } catch (e) {
      print('Error creating thumbnail with flutter_image_compress: $e');
      // Don't throw error, just log it - thumbnail creation failure shouldn't stop main file save
    }
  }

  // Public: pick a file and save into categorized subfolder
  Future<File?> pickAndSaveCategorized() async {
    final result = await FilePicker.platform.pickFiles(withData: false); // [17]
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final srcPath = picked.path;
    if (srcPath == null) return null;

    final dirName = await _dirNameForPath(srcPath);
    final subdir = await _ensureSubdir(dirName);

    // Generate unique filename to avoid conflicts
    String fileName = picked.name;
    String targetPath = p.join(subdir.path, fileName);

    // If file already exists, add timestamp to make it unique
    if (await File(targetPath).exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      fileName = '${nameWithoutExt}_$timestamp$extension';
      targetPath = p.join(subdir.path, fileName);
    }

    final copiedFile = await File(srcPath).copy(targetPath); // [13]

    // Create thumbnail if it's an image
    if (dirName == 'images') {
      await _createThumbnail(copiedFile, fileName);
    }

    return copiedFile;
  }

  // Save an existing File categorized
  Future<File> saveFileCategorized(File source) async {
    print('saveFileCategorized: Starting with source: ${source.path}');

    final dirName = await _dirNameForPath(source.path);
    print('saveFileCategorized: Determined directory name: $dirName');

    final subdir = await _ensureSubdir(dirName);
    print('saveFileCategorized: Ensured subdirectory: ${subdir.path}');

    // Generate unique filename to avoid conflicts
    String fileName = p.basename(source.path);
    String targetPath = p.join(subdir.path, fileName);
    print('saveFileCategorized: Initial target path: $targetPath');

    // If file already exists, add timestamp to make it unique
    if (await File(targetPath).exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      fileName = '${nameWithoutExt}_$timestamp$extension';
      targetPath = p.join(subdir.path, fileName);
      print('saveFileCategorized: File exists, using unique name: $targetPath');
    }

    final copiedFile = await source.copy(targetPath);
    print('saveFileCategorized: File copied successfully to: ${copiedFile.path}');
    print('saveFileCategorized: File exists after copy: ${await copiedFile.exists()}');

    // Create thumbnail if it's an image
    if (dirName == 'images') {
      await _createThumbnail(copiedFile, fileName);
    }

    return copiedFile;
  }

  // Save bytes with a given filename, categorized by extension in the name
  Future<File> saveBytesCategorized(String fileName, List<int> bytes, {bool flush = true}) async {
    final tempDocs = await _docsDir();
    final tmpProbePath = p.join(tempDocs.path, fileName); // used for mime probe by name
    final dirName = await _dirNameForPath(tmpProbePath);
    final subdir = await _ensureSubdir(dirName);
    final file = File(p.join(subdir.path, fileName));
    await file.create(recursive: true);
    final savedFile = await file.writeAsBytes(bytes, flush: flush);

    // Create thumbnail if it's an image
    if (dirName == 'images') {
      await _createThumbnail(savedFile, fileName);
    }

    return savedFile;
  }

  // Helper: list files by category
  Future<List<File>> listCategory(String category) async {
    final subdir = await _ensureSubdir(category); // images/audio/video/other
    final entries = await subdir.list().toList();
    return entries.whereType<File>().toList();
  }

  Future<List<File>> listImages() => listCategory('images');
  Future<List<File>> listThumbnails() => listCategory('thumbnails');
  Future<List<File>> listAudio() => listCategory('audio');
  Future<List<File>> listVideo() => listCategory('video');
  Future<List<File>> listOther() => listCategory('other');

  // Get absolute paths for subfolders
  Future<String> imagesDirPath() async => (await _ensureSubdir('images')).path;
  Future<String> thumbnailsDirPath() async => (await _ensureSubdir('thumbnails')).path;
  Future<String> audioDirPath() async => (await _ensureSubdir('audio')).path;
  Future<String> videoDirPath() async => (await _ensureSubdir('video')).path;
  Future<String> otherDirPath() async => (await _ensureSubdir('other')).path;

  // Get thumbnail path for a given image filename
  Future<String?> getThumbnailPath(String imageFileName) async {
    final thumbnailsDir = await thumbnailsDirPath();
    final nameWithoutExt = p.basenameWithoutExtension(imageFileName);
    final thumbnailFileName = 'thumb_$nameWithoutExt.jpg';
    final thumbnailPath = p.join(thumbnailsDir, thumbnailFileName);

    final thumbnailFile = File(thumbnailPath);
    if (await thumbnailFile.exists()) {
      return thumbnailPath;
    }
    return null;
  }

  // Debug method to check storage paths and contents
  Future<Map<String, dynamic>> debugStorageInfo() async {
    final docsDir = await _docsDir();
    final imagesDir = await _ensureSubdir('images');
    final imageFiles = await listImages();
    
    return {
      'documentsPath': docsDir.path,
      'imagesPath': imagesDir.path,
      'imageCount': imageFiles.length,
      'imageFiles': imageFiles.map((f) => f.path).toList(),
      'imagesDirectoryExists': await imagesDir.exists(),
    };
  }
}
