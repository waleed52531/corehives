import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptPicker extends StatelessWidget {
  final File? file;
  final double? uploadProgress; // null = not uploading
  final bool failed;
  final ValueChanged<File?> onPicked;
  final VoidCallback? onRetry;

  const ReceiptPicker({
    super.key,
    required this.file,
    required this.onPicked,
    this.uploadProgress,
    this.failed = false,
    this.onRetry,
  });

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) onPicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(file!, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: uploadProgress != null
                ? LinearProgressIndicator(value: uploadProgress)
                : failed
                    ? Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          const Expanded(child: Text('Upload failed', style: TextStyle(color: Colors.red))),
                          TextButton(onPressed: onRetry, child: const Text('Retry')),
                        ],
                      )
                    : const Text('Ready to upload'),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => onPicked(null)),
        ],
      ),
    );
  }
}
