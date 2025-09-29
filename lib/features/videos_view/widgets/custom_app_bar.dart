import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<VideoViewProvider>(context);
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: const Text(
        "Video Manager",
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: false,
      actions: _buildAppBarActions(context, provider),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, VideoViewProvider provider) {
    List<Widget> actions = [];

    actions.add(
      Container(
        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
          onPressed: provider.isLoading ? null : () => provider.refreshVideos(),
          tooltip: 'Refresh',
        ),
      ),
    );
    if (provider.selectedVideos.isNotEmpty) {
      actions.add(
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.clear_all, color: Color(0xFFEF4444)),
            onPressed: () => provider.clearAllVideos(),
            tooltip: 'Clear All',
          ),
        ),
      );
    }

    return actions;
  }
}
