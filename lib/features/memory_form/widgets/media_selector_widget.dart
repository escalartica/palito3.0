import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaSelectorWidget extends StatelessWidget {
  final List<String> imageUrls;
  final String? videoUrl;
  final Function(File?, bool) onMediaSelected;

  const MediaSelectorWidget({super.key, required this.imageUrls, this.videoUrl, required this.onMediaSelected});

  Future<void> _pickMedia(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      onMediaSelected(File(file.path), false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasMedia = imageUrls.isNotEmpty || videoUrl != null;
    return GestureDetector(
      onTap: () => _pickMedia(context),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: hasMedia 
            ? const Text("Media seleccionado ✅") 
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(Icons.add_a_photo), Text("Añadir foto o video")],
              ),
        ),
      ),
    );
  }
}