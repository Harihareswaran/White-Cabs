import 'dart:io';
import 'package:flutter/material.dart';

class FullscreenImage extends StatelessWidget {
  final String imagePath;

  const FullscreenImage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
        backgroundColor: Colors.blue[700],
      ),
      body: Center(
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}