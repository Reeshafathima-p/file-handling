import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';
import '../../../service/FileStorageService.dart';

class FullImageViewScreen extends StatefulWidget {
  final File imageFile;
  final int imageIndex;

  const FullImageViewScreen({
    super.key,
    required this.imageFile,
    required this.imageIndex,
  });

  @override
  State<FullImageViewScreen> createState() => _FullImageViewScreenState();
}

class _FullImageViewScreenState extends State<FullImageViewScreen> {
  Uint8List? _decryptedBytes;
  bool _isLoading = true;
  String? _errorMessage;
  final FileStorageService _fileService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    _decryptImage();
  }

  Future<void> _decryptImage() async {
    try {
      print('FullImageView: Decrypting image: ${widget.imageFile.path}');
      _decryptedBytes = Uint8List.fromList(
        await _fileService.readEncryptedFile(widget.imageFile.path)
      );
      print('FullImageView: Successfully decrypted ${widget.imageFile.path}');
    } catch (e) {
      _errorMessage = 'Failed to decrypt image: $e';
      print('FullImageView: Error decrypting: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.imageFile.path);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          fileName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showImageInfo(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Decrypting image...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_decryptedBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load image',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Use PhotoView for advanced zoom/pan functionality
    return PhotoView(
      imageProvider: MemoryImage(_decryptedBytes!),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to display image',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageInfo(BuildContext context) async {
    final fileName = path.basename(widget.imageFile.path);
    final fileSize = await widget.imageFile.length();
    final lastModified = await widget.imageFile.lastModified();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: $fileName'),
            Text('Size: ${_formatFileSize(fileSize)}'),
            Text('Modified: ${_formatDate(lastModified)}'),
            Text('Index: ${widget.imageIndex + 1}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
