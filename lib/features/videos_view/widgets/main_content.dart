import 'package:flutter/material.dart';
import '../controller/video_view_provider.dart';
import 'package:provider/provider.dart';
import 'header.dart';
import 'content_area.dart';

class MainContent extends StatelessWidget {
  const MainContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Header(),
          const SizedBox(height: 24),
          Expanded(child: ContentArea()),
        ],
      ),
    );
  }
}
