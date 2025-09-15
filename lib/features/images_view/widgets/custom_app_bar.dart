import 'package:flutter/material.dart';
import '../controller/image_view_provider.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImageViewProvider>(context);
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
        "File Manager",
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

  List<Widget> _buildAppBarActions(BuildContext context, ImageViewProvider provider) {
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
          onPressed: provider.isLoading ? null : () => provider.refreshImages(),
          tooltip: 'Refresh',
        ),
      ),
    );
    if (provider.selectedImages.isNotEmpty) {
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
            onPressed: () => provider.clearAllImages(),
            tooltip: 'Clear All',
          ),
        ),
      );
    }

    return actions;
  }


  Widget _buildStatusCard(String title, int encrypted, int total, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            '$encrypted/$total',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTestResult(BuildContext context, String title, Map<String, dynamic> result) {
    final message = result['message'] ?? 'Test completed';
    final isSuccess = result['encryptionWorking'] == true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              if (result.containsKey('originalSize') && result.containsKey('savedSize')) ...[
                const SizedBox(height: 12),
                Text(
                  'Original: ${result['originalSize']} bytes\nEncrypted: ${result['savedSize']} bytes',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showVerificationResult(BuildContext context, Map<String, dynamic> result) {
    final encryptedImages = result['imagesEncrypted'] as List<String>? ?? [];
    final notEncryptedImages = result['imagesNotEncrypted'] as List<String>? ?? [];
    final encryptedThumbs = result['thumbnailsEncrypted'] as List<String>? ?? [];
    final notEncryptedThumbs = result['thumbnailsNotEncrypted'] as List<String>? ?? [];

    final totalImages = result['totalImages'] ?? 0;
    final totalThumbs = result['totalThumbnails'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Encryption Verification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📊 Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Images: $totalImages total'),
                Text('Thumbnails: $totalThumbs total'),
                const SizedBox(height: 12),

                if (encryptedImages.isNotEmpty) ...[
                  Text('✅ Encrypted Images (${encryptedImages.length}):',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ...encryptedImages.map((name) => Text('• $name', style: TextStyle(fontSize: 12))),
                  const SizedBox(height: 8),
                ],

                if (notEncryptedImages.isNotEmpty) ...[
                  Text('❌ Unencrypted Images (${notEncryptedImages.length}):',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ...notEncryptedImages.map((name) => Text('• $name', style: TextStyle(fontSize: 12))),
                  const SizedBox(height: 8),
                ],

                if (encryptedThumbs.isNotEmpty) ...[
                  Text('✅ Encrypted Thumbnails (${encryptedThumbs.length}):',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ...encryptedThumbs.map((name) => Text('• $name', style: TextStyle(fontSize: 12))),
                  const SizedBox(height: 8),
                ],

                if (notEncryptedThumbs.isNotEmpty) ...[
                  Text('❌ Unencrypted Thumbnails (${notEncryptedThumbs.length}):',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ...notEncryptedThumbs.map((name) => Text('• $name', style: TextStyle(fontSize: 12))),
                ],

                if (encryptedImages.isEmpty && notEncryptedImages.isEmpty &&
                    encryptedThumbs.isEmpty && notEncryptedThumbs.isEmpty) ...[
                  const Text('📁 No files found to verify'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
}
