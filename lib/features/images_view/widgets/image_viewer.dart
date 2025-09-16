import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../../../service/FileStorageService.dart';

class EncryptedImageViewer extends StatefulWidget {
  final File encryptedFile;
  final String? title;
  final double? width;
  final double? height;
  final BoxFit fit;

  const EncryptedImageViewer({
    super.key,
    required this.encryptedFile,
    this.title,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  State<EncryptedImageViewer> createState() => _EncryptedImageViewerState();
}

class _EncryptedImageViewerState extends State<EncryptedImageViewer> {
  List<int>? _decryptedBytes;
  bool _isLoading = true;
  String? _errorMessage;
  final FileStorageService _fileService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    _decryptAndLoadImage();
  }

  Future<void> _decryptAndLoadImage() async {
    try {
      print('EncryptedImageViewer: Starting decryption for file: ${widget.encryptedFile.path}');
      print('EncryptedImageViewer: File exists: ${await widget.encryptedFile.exists()}');
      print('EncryptedImageViewer: File size: ${await widget.encryptedFile.length()} bytes');

      // Read and decrypt the encrypted file
      _decryptedBytes = await _fileService.readEncryptedFile(widget.encryptedFile.path);

      print('EncryptedImageViewer: Successfully decrypted ${widget.encryptedFile.path}');
      print('EncryptedImageViewer: Decrypted size: ${_decryptedBytes?.length ?? 0} bytes');

      // Validate that decrypted data looks like image data
      if (_decryptedBytes != null && _decryptedBytes!.isNotEmpty) {
        if (_decryptedBytes!.length > 4) {
          final header = _decryptedBytes!.sublist(0, 4);
          print('EncryptedImageViewer: Image header bytes: $header');

          // Check for common image signatures
          bool isValidImage = false;
          if (header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8) {
            isValidImage = true; // JPEG
            print('EncryptedImageViewer: Detected JPEG format');
          } else if (header.length >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
            isValidImage = true; // PNG
            print('EncryptedImageViewer: Detected PNG format');
          } else if (header.length >= 4 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) {
            isValidImage = true; // GIF
            print('EncryptedImageViewer: Detected GIF format');
          }

          if (!isValidImage) {
            print('EncryptedImageViewer: WARNING - Decrypted data does not appear to be valid image data!');
            print('EncryptedImageViewer: Checking if file is actually encrypted...');

            // Check if the original file contains valid image data (not encrypted)
            final rawBytes = await widget.encryptedFile.readAsBytes();
            if (rawBytes.length > 4) {
              final rawHeader = rawBytes.sublist(0, 4);
              print('EncryptedImageViewer: Raw file header: $rawHeader');
              if ((rawHeader.length >= 2 && rawHeader[0] == 0xFF && rawHeader[1] == 0xD8) ||
                  (rawHeader.length >= 4 && rawHeader[0] == 0x89 && rawHeader[1] == 0x50 && rawHeader[2] == 0x4E && rawHeader[3] == 0x47) ||
                  (rawHeader.length >= 4 && rawHeader[0] == 0x47 && rawHeader[1] == 0x49 && rawHeader[2] == 0x46 && rawHeader[3] == 0x38)) {
                print('EncryptedImageViewer: File appears to be unencrypted! Using raw bytes instead.');
                _decryptedBytes = rawBytes;
              } else {
                _errorMessage = 'Invalid image data';
                _decryptedBytes = null;
              }
            } else {
              _errorMessage = 'File too small';
              _decryptedBytes = null;
            }
          }
        }
      } else {
        _errorMessage = 'Failed to decrypt file';
        print('EncryptedImageViewer: Decryption returned null or empty data');
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      print('EncryptedImageViewer: Error decrypting file: $e');
      _decryptedBytes = null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text(
                    'Decrypting image...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : _decryptedBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    Uint8List.fromList(_decryptedBytes!),
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    errorBuilder: (context, error, stackTrace) {
                      print('EncryptedImageViewer: Image.memory error: $error');
                      return Container(
                        width: widget.width,
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to display image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage ?? 'Failed to decrypt image',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          path.basename(widget.encryptedFile.path),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
