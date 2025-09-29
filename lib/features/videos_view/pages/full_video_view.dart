import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../../../service/FileStorageService.dart';

class FullVideoViewScreen extends StatefulWidget {
  final File videoFile;
  final int videoIndex;

  const FullVideoViewScreen({
    super.key,
    required this.videoFile,
    required this.videoIndex,
  });

  @override
  State<FullVideoViewScreen> createState() => _FullVideoViewScreenState();
}

class _FullVideoViewScreenState extends State<FullVideoViewScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlaying = false;
  final FileStorageService _fileService = FileStorageService.instance;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      print('FullVideoView: Initializing video: ${widget.videoFile.path}');

      // Decrypt the video file
      final decryptedBytes = await _fileService.readEncryptedFile(widget.videoFile.path);

      // Create a temporary file for the decrypted video
      final tempDir = await Directory.systemTemp.createTemp();
      final tempVideoFile = File('${tempDir.path}/temp_video.mp4');
      await tempVideoFile.writeAsBytes(decryptedBytes);

      // Initialize video player with the decrypted file
      _controller = VideoPlayerController.file(tempVideoFile)
        ..initialize().then((_) {
          setState(() {
            _isLoading = false;
          });
          print('FullVideoView: Video initialized successfully');
        })
        ..addListener(() {
          if (mounted) {
            setState(() {
              _isPlaying = _controller!.value.isPlaying;
            });
          }
        });

    } catch (e) {
      _errorMessage = 'Failed to initialize video: $e';
      print('FullVideoView: Error initializing video: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(widget.videoFile.path);

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
            onPressed: () => _showVideoInfo(context),
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
              'Decrypting and loading video...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_file,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Failed to load video',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        // Play/Pause overlay
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Video controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Progress bar
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 8),
                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_controller!.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_controller!.value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showVideoInfo(BuildContext context) async {
    final fileName = path.basename(widget.videoFile.path);
    final fileSize = await widget.videoFile.length();
    final lastModified = await widget.videoFile.lastModified();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: $fileName'),
            Text('Size: ${_formatFileSize(fileSize)}'),
            Text('Modified: ${_formatDate(lastModified)}'),
            Text('Index: ${widget.videoIndex + 1}'),
            if (_controller != null && _controller!.value.isInitialized) ...[
              Text('Duration: ${_formatDuration(_controller!.value.duration)}'),
              Text('Resolution: ${_controller!.value.size.width.toInt()} x ${_controller!.value.size.height.toInt()}'),
            ],
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
