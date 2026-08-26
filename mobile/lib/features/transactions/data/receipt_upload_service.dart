import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

class ReceiptUploadResult {
  final String url;
  final String storagePath;
  ReceiptUploadResult(this.url, this.storagePath);
}

class ReceiptUploadService {
  final FirebaseStorage _storage;
  ReceiptUploadService(this._storage);

  /// Compresses then uploads to receipts/{year}/{month}/{transactionId}/{fileName}.
  /// Throws on failure — caller is responsible for marking attachmentStatus=failed
  /// without losing the underlying transaction (transaction is saved first).
  Future<ReceiptUploadResult> uploadReceipt({
    required File file,
    required String transactionId,
    required int year,
    required int month,
    void Function(double progress)? onProgress,
  }) async {
    final compressed = await _compress(file);
    final ext = p.extension(compressed.path).toLowerCase();
    String contentType = 'image/jpeg';
    if (ext == '.png') {
      contentType = 'image/png';
    } else if (ext == '.webp') {
      contentType = 'image/webp';
    } else if (ext == '.gif') {
      contentType = 'image/gif';
    } else if (ext == '.heic' || ext == '.heif') {
      contentType = 'image/heic';
    }

    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}$ext';
    final storagePath =
        'receipts/$year/${month.toString().padLeft(2, '0')}/$transactionId/$fileName';

    final ref = _storage.ref(storagePath);
    final task = ref.putFile(
      compressed,
      SettableMetadata(contentType: contentType),
    );

    task.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) {
        onProgress?.call(snap.bytesTransferred / snap.totalBytes);
      }
    });

    final snapshot = await task;
    final url = await snapshot.ref.getDownloadURL();
    return ReceiptUploadResult(url, storagePath);
  }

  Future<File> _compress(File file) async {
    try {
      final targetPath = '${file.path}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      print('Receipt Upload: Compression failed, falling back to original: $e');
      return file;
    }
  }
}
