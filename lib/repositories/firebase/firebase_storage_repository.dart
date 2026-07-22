/// Firebase implementation of [IStorageRepository].
/// Wraps Firebase Storage operations.

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../i_storage_repository.dart';

class FirebaseStorageRepository implements IStorageRepository {
  final FirebaseStorage _storage;

  FirebaseStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadFile(String path, List<int> bytes, {String? contentType}) async {
    final ref = _storage.ref(path);
    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;
    await ref.putData(Uint8List.fromList(bytes), metadata);
    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadProfilePhoto(String userId, List<int> bytes) async {
    return uploadFile('profile_photos/$userId.jpg', bytes, contentType: 'image/jpeg');
  }

  @override
  Future<String> uploadVerificationDocument(String userId, List<int> bytes, String fileName) async {
    final ext = fileName.split('.').last;
    return uploadFile(
      'verification_docs/$userId/$fileName',
      bytes,
      contentType: _contentTypeForExtension(ext),
    );
  }

  @override
  Future<void> deleteFile(String path) async {
    await _storage.ref(path).delete();
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return await _storage.ref(path).getDownloadURL();
  }

  String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }
}
