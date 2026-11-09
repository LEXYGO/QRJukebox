//gets accesed from PlayerPage to show cover in full screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullscreenCover extends StatelessWidget {
  final List<int> imageBytes;
  const FullscreenCover({super.key, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: 'cover',
            child: Image.memory(
              Uint8List.fromList(imageBytes),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}