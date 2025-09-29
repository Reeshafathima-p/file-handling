import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/video_view_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/main_content.dart';
import '../widgets/add_button.dart';
import '../widgets/video_picker_overlay.dart';
import '../widgets/loading_overlay.dart';

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  State<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen>
    with TickerProviderStateMixin {
  late VideoViewProvider provider;

  @override
  void initState() {
    super.initState();
    provider = VideoViewProvider();
    provider.setAnimationController(
      AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadExistingVideos();
    });
  }

  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VideoViewProvider>(
      create: (_) => provider,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: const CustomAppBar(),
        body: Consumer<VideoViewProvider>(
          builder: (context, provider, child) {
            return Stack(
              children: [
                const MainContent(),
                if (provider.isVideoPickerVisible) const VideoPickerOverlay(),
                if (provider.isLoading) const LoadingOverlay(),
              ],
            );
          },
        ),
        floatingActionButton: const AddButton(),
      ),
    );
  }
}
