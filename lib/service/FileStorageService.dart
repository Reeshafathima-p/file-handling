import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class FileStorageService {
  FileStorageService._();
  static final instance = FileStorageService._();

  // Encryption key - using a fixed key for simplicity (in production, use a secure key management system)
  static final _encryptionKey = encrypt.Key.fromUtf8('0123456789abcdef0123456789abcdef'); // 32 bytes
  static final _iv = encrypt.IV.fromUtf8('0123456789abcdef'); // 16 bytes IV

  // Get encrypter instance
  encrypt.Encrypter get _encrypter => encrypt.Encrypter(encrypt.AES(_encryptionKey));

  // Encrypt data
  List<int> _encryptData(List<int> data) {
    try {
      final uint8Data = Uint8List.fromList(data);
      final encrypted = _encrypter.encryptBytes(uint8Data, iv: _iv);
      print('FileStorageService: Encrypted ${data.length} bytes to ${encrypted.bytes.length} bytes');
      return encrypted.bytes;
    } catch (e) {
      print('FileStorageService: Error encrypting data: $e');
      rethrow;
    }
  }

  // Decrypt data
  List<int> _decryptData(List<int> encryptedData) {
    try {
      print('FileStorageService: Attempting to decrypt ${encryptedData.length} bytes');
      print('FileStorageService: First 10 encrypted bytes: ${encryptedData.sublist(0, encryptedData.length > 10 ? 10 : encryptedData.length)}');
      print('FileStorageService: Encrypted data type: ${encryptedData.runtimeType}');

      // Ensure we have Uint8List for encryption library
      final uint8Data = encryptedData is Uint8List ? encryptedData : Uint8List.fromList(encryptedData);
      final encrypted = encrypt.Encrypted(uint8Data);
      final decrypted = _encrypter.decryptBytes(encrypted, iv: _iv);

      print('FileStorageService: Successfully decrypted to ${decrypted.length} bytes');
      print('FileStorageService: First 10 decrypted bytes: ${decrypted.sublist(0, decrypted.length > 10 ? 10 : decrypted.length)}');

      return decrypted;
    } catch (e) {
      print('FileStorageService: Error decrypting data: $e');
      print('FileStorageService: Encrypted data length: ${encryptedData.length}');
      print('FileStorageService: Encrypted data type: ${encryptedData.runtimeType}');
      rethrow;
    }
  }

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

      // Decrypt the image data first before compression
      final decryptedBytes = _decryptData(originalBytes);

      // Create a temporary file with decrypted data for compression
      final tempDir = await getTemporaryDirectory();
      final tempImagePath = p.join(tempDir.path, 'temp_decrypted_$originalFileName');
      final tempImageFile = File(tempImagePath);
      await tempImageFile.writeAsBytes(decryptedBytes);

      try {
        // Use flutter_image_compress for maximum compression with resized dimensions
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          tempImageFile.absolute.path,
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

        // Encrypt the compressed thumbnail before saving
        final encryptedThumbnailBytes = _encryptData(compressedBytes);

        // Save encrypted thumbnail
        final thumbnailFile = File(thumbnailPath);
        await thumbnailFile.writeAsBytes(encryptedThumbnailBytes);

        final compressedSize = compressedBytes.length;
        final encryptedSize = encryptedThumbnailBytes.length;
        final compressionRatio = ((originalSize - compressedSize) / originalSize * 100).round();

        print('Thumbnail created, compressed, and encrypted: $thumbnailPath');
        print('Original size: ${originalSize} bytes, Compressed size: ${compressedSize} bytes, Encrypted size: ${encryptedSize} bytes');
        print('Compression ratio: ${compressionRatio}% size reduction');
      } finally {
        // Clean up temporary file
        if (await tempImageFile.exists()) {
          await tempImageFile.delete();
        }
      }
    } catch (e) {
      print('Error creating thumbnail with flutter_image_compress: $e');
      // Don't throw error, just log it - thumbnail creation failure shouldn't stop main file save
    }
  }

  // Create image thumbnail from video for grid display
  Future<void> _createVideoThumbnail(File sourceFile, String originalFileName) async {
    try {
      final mime = await _detectMime(sourceFile.path);
      if (mime == null || !mime.startsWith('video/')) {
        return; // Not a video, skip thumbnail creation
      }

      // Create video_thumbnails directory (same as image thumbnails)
      final videoThumbnailsDir = await _ensureSubdir('video_thumbnails');

      // Generate thumbnail filename: vthumb_[original_filename].jpg
      final nameWithoutExt = p.basenameWithoutExtension(originalFileName);
      final thumbnailFileName = 'vthumb_$nameWithoutExt.jpg';
      final thumbnailPath = p.join(videoThumbnailsDir.path, thumbnailFileName);

      // Decrypt the video data first
      final encryptedBytes = await sourceFile.readAsBytes();
      final decryptedBytes = _decryptData(encryptedBytes);

      // Create a temporary file with decrypted data for thumbnail generation
      final tempDir = await getTemporaryDirectory();
      final tempVideoPath = p.join(tempDir.path, 'temp_decrypted_$originalFileName');
      final tempVideoFile = File(tempVideoPath);
      await tempVideoFile.writeAsBytes(decryptedBytes);

      try {
        // Generate image thumbnail from video using video_thumbnail package
        final thumbnailBytes = await VideoThumbnail.thumbnailData(
          video: tempVideoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 300, // Reasonable size for grid display
          quality: 75,
          timeMs: 1000, // Get thumbnail at 1 second
        );

        if (thumbnailBytes == null) {
          print('Failed to generate video thumbnail image: ${sourceFile.path}');
          return;
        }

        // Further compress the thumbnail image using flutter_image_compress
        final compressedThumbnailBytes = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(thumbnailBytes),
          quality: 70, // Good quality for thumbnails
          format: CompressFormat.jpeg,
        );

        final finalThumbnailBytes = compressedThumbnailBytes ?? thumbnailBytes;

        // Encrypt the thumbnail image before saving
        final encryptedThumbnailBytes = _encryptData(finalThumbnailBytes);

        // Save encrypted thumbnail image
        final thumbnailFile = File(thumbnailPath);
        await thumbnailFile.writeAsBytes(encryptedThumbnailBytes);

        print('Video thumbnail image created, compressed, and encrypted: $thumbnailPath');
        print('Thumbnail size: ${finalThumbnailBytes.length} bytes, Encrypted size: ${encryptedThumbnailBytes.length} bytes');
      } finally {
        // Clean up temporary file
        if (await tempVideoFile.exists()) {
          await tempVideoFile.delete();
        }
      }
    } catch (e) {
      print('Error creating video thumbnail image: $e');
      // Don't throw error, just log it - thumbnail creation failure shouldn't stop main file save
    }
  }

  // Public: pick a file and save into categorized subfolder
  Future<File?> pickAndSaveCategorized({bool deleteOriginal = false}) async {
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

    // Read file content and encrypt it
    final sourceFile = File(srcPath);
    final originalBytes = await sourceFile.readAsBytes();
    final encryptedBytes = _encryptData(originalBytes);

    // Save encrypted content
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(encryptedBytes);

    print('File encrypted and saved: $targetPath');
    print('Original size: ${originalBytes.length} bytes, Encrypted size: ${encryptedBytes.length} bytes');

    // Create thumbnail if it's an image
    if (dirName == 'images') {
      await _createThumbnail(targetFile, fileName);
    }

    // Delete the original file if requested
    if (deleteOriginal) {
      try {
        await sourceFile.delete();
        print('Original file deleted from storage: $srcPath');
      } catch (e) {
        print('Failed to delete original file: $srcPath, error: $e');
      }
    }

    return targetFile;
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

    // Read file content and encrypt it
    final originalBytes = await source.readAsBytes();
    final encryptedBytes = _encryptData(originalBytes);

    // Save encrypted content
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(encryptedBytes);

    print('File encrypted and saved: $targetPath');
    print('Original size: ${originalBytes.length} bytes, Encrypted size: ${encryptedBytes.length} bytes');

    // Create thumbnail if it's an image
    if (dirName == 'images') {
      await _createThumbnail(targetFile, fileName);
    }
    // Create video thumbnail if it's a video
    else if (dirName == 'video') {
      await _createVideoThumbnail(targetFile, fileName);
    }

    return targetFile;
  }

  // Save bytes with a given filename, categorized by extension in the name
  Future<File> saveBytesCategorized(String fileName, List<int> bytes, {bool flush = true}) async {
    final tempDocs = await _docsDir();
    final tmpProbePath = p.join(tempDocs.path, fileName); // used for mime probe by name
    final dirName = await _dirNameForPath(tmpProbePath);
    final subdir = await _ensureSubdir(dirName);

    // Encrypt the bytes before saving
    final encryptedBytes = _encryptData(bytes);

    final file = File(p.join(subdir.path, fileName));
    await file.create(recursive: true);
    final savedFile = await file.writeAsBytes(encryptedBytes, flush: flush);

    print('Bytes encrypted and saved: ${savedFile.path}');
    print('Original size: ${bytes.length} bytes, Encrypted size: ${encryptedBytes.length} bytes');

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
  Future<List<File>> listVideoThumbnails() => listCategory('video_thumbnails');
  Future<List<File>> listOther() => listCategory('other');

  // Get absolute paths for subfolders
  Future<String> imagesDirPath() async => (await _ensureSubdir('images')).path;
  Future<String> thumbnailsDirPath() async => (await _ensureSubdir('thumbnails')).path;
  Future<String> audioDirPath() async => (await _ensureSubdir('audio')).path;
  Future<String> videoDirPath() async => (await _ensureSubdir('video')).path;
  Future<String> videoThumbnailsDirPath() async => (await _ensureSubdir('video_thumbnails')).path;
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

    // Fallback: try to find any thumbnail file that starts with the same name
    final thumbnailDir = Directory(thumbnailsDir);
    if (await thumbnailDir.exists()) {
      final files = await thumbnailDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          if (fileName.startsWith('thumb_$nameWithoutExt.')) {
            return file.path;
          }
        }
      }
    }

    return null;
  }

  // Get video thumbnail path for a given video filename
  Future<String?> getVideoThumbnailPath(String videoFileName) async {
    final videoThumbnailsDir = await videoThumbnailsDirPath();
    final nameWithoutExt = p.basenameWithoutExtension(videoFileName);
    final thumbnailFileName = 'vthumb_$nameWithoutExt.jpg';
    final thumbnailPath = p.join(videoThumbnailsDir, thumbnailFileName);

    final thumbnailFile = File(thumbnailPath);
    if (await thumbnailFile.exists()) {
      return thumbnailPath;
    }

    // Fallback: try to find any thumbnail file that starts with the same name
    final thumbnailDir = Directory(videoThumbnailsDir);
    if (await thumbnailDir.exists()) {
      final files = await thumbnailDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          if (fileName.startsWith('vthumb_$nameWithoutExt.')) {
            return file.path;
          }
        }
      }
    }

    return null;
  }

  // Decrypt and read file content
  Future<List<int>> readEncryptedFile(String filePath) async {
    print('readEncryptedFile: Attempting to read file: $filePath');
    final file = File(filePath);
    if (!await file.exists()) {
      print('readEncryptedFile: File does not exist: $filePath');
      throw Exception('File does not exist: $filePath');
    }

    final encryptedBytes = await file.readAsBytes();
    print('readEncryptedFile: Read ${encryptedBytes.length} encrypted bytes');
    if (encryptedBytes.isNotEmpty) {
      print('readEncryptedFile: First 10 bytes of encrypted data: ${encryptedBytes.sublist(0, encryptedBytes.length > 10 ? 10 : encryptedBytes.length)}');
    }
    final decryptedBytes = _decryptData(encryptedBytes);
    print('readEncryptedFile: Decrypted to ${decryptedBytes.length} bytes');
    if (decryptedBytes.isNotEmpty) {
      print('readEncryptedFile: First 10 bytes of decrypted data: ${decryptedBytes.sublist(0, decryptedBytes.length > 10 ? 10 : decryptedBytes.length)}');
    }
    return decryptedBytes;
  }

  // Decrypt and read thumbnail content
  Future<List<int>> readEncryptedThumbnail(String imageFileName) async {
    final thumbnailPath = await getThumbnailPath(imageFileName);
    if (thumbnailPath == null) {
      throw Exception('Thumbnail does not exist for: $imageFileName');
    }

    return await readEncryptedFile(thumbnailPath);
  }

  // Get decrypted image bytes for display
  Future<List<int>> getDecryptedImageBytes(String imageFileName) async {
    final imagesDir = await imagesDirPath();
    final imagePath = p.join(imagesDir, imageFileName);
    print('getDecryptedImageBytes: imagesDir = $imagesDir');
    print('getDecryptedImageBytes: imageFileName = $imageFileName');
    print('getDecryptedImageBytes: constructed imagePath = $imagePath');

    return await readEncryptedFile(imagePath);
  }

  // Verify if files are encrypted by checking file headers
  Future<Map<String, dynamic>> verifyEncryption() async {
    final imagesDir = await _ensureSubdir('images');
    final thumbnailsDir = await _ensureSubdir('thumbnails');

    final imageFiles = await listImages();
    final thumbnailFiles = await listThumbnails();

    Map<String, dynamic> results = {
      'imagesEncrypted': <String>[],
      'imagesNotEncrypted': <String>[],
      'thumbnailsEncrypted': <String>[],
      'thumbnailsNotEncrypted': <String>[],
      'totalImages': imageFiles.length,
      'totalThumbnails': thumbnailFiles.length,
    };

    // Check image files
    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      final isEncrypted = _isFileEncrypted(bytes);
      final fileName = p.basename(file.path);

      if (isEncrypted) {
        results['imagesEncrypted'].add(fileName);
      } else {
        results['imagesNotEncrypted'].add(fileName);
      }
    }

    // Check thumbnail files
    for (final file in thumbnailFiles) {
      final bytes = await file.readAsBytes();
      final isEncrypted = _isFileEncrypted(bytes);
      final fileName = p.basename(file.path);

      if (isEncrypted) {
        results['thumbnailsEncrypted'].add(fileName);
      } else {
        results['thumbnailsNotEncrypted'].add(fileName);
      }
    }

    return results;
  }

  // Helper method to check if file content appears to be encrypted
  bool _isFileEncrypted(List<int> bytes) {
    if (bytes.length < 16) return false;

    // Check if the first 16 bytes match our IV pattern (random bytes)
    // Encrypted files should not have recognizable image headers
    final header = bytes.sublist(0, 16);

    // Common image file signatures that should NOT be present in encrypted files
    final imageSignatures = [
      [0xFF, 0xD8, 0xFF], // JPEG SOI
      [0x89, 0x50, 0x4E, 0x47], // PNG
      [0x47, 0x49, 0x46, 0x38], // GIF
      [0x42, 0x4D], // BMP
      [0x52, 0x49, 0x46, 0x46], // WebP (starts with RIFF)
    ];

    for (final signature in imageSignatures) {
      if (header.length >= signature.length) {
        bool matches = true;
        for (int i = 0; i < signature.length; i++) {
          if (header[i] != signature[i]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          return false; // File has recognizable image header, not encrypted
        }
      }
    }

    return true; // No recognizable headers found, likely encrypted
  }

  // Test encryption by creating and verifying a test file
  Future<Map<String, dynamic>> testEncryption() async {
    try {
      // Create test data
      final testData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]); // JPEG header
      final testFileName = 'encryption_test.jpg';

      // Save encrypted test file
      final savedFile = await saveBytesCategorized(testFileName, testData);

      // Read back the saved file
      final savedBytes = await savedFile.readAsBytes();

      // Check if the saved file is encrypted
      final isEncrypted = _isFileEncrypted(savedBytes);

      // Try to display as image (this should fail if encrypted)
      bool canDisplayAsImage = false;
      try {
        // This is just a simulation - in reality Image.file would fail with encrypted data
        canDisplayAsImage = !isEncrypted;
      } catch (e) {
        canDisplayAsImage = false;
      }

      return {
        'testFilePath': savedFile.path,
        'originalSize': testData.length,
        'savedSize': savedBytes.length,
        'isEncrypted': isEncrypted,
        'canDisplayAsImage': canDisplayAsImage,
        'encryptionWorking': isEncrypted && !canDisplayAsImage,
        'message': isEncrypted
            ? '✅ Encryption is working - file is encrypted and cannot be displayed as image'
            : '❌ Encryption is NOT working - file appears to be unencrypted'
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'message': '❌ Error during encryption test'
      };
    }
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
