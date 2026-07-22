/// Supabase implementation of [IStorageRepository].
/// Uses Supabase Storage buckets.

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i_storage_repository.dart';

class SupabaseStorageRepository implements IStorageRepository {
  final SupabaseClient _client;
  static const _bucketName = 'blood-bridge-files';

  SupabaseStorageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<String> uploadFile(String path, List<int> bytes, {String? contentType}) async {
    await _client.storage
        .from(_bucketName)
        .uploadBinary(path, Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType));
    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  @override
  Future<String> uploadProfilePhoto(String userId, List<int> bytes) async {
    return uploadFile('profile_photos/$userId.jpg', bytes, contentType: 'image/jpeg');
  }

  @override
  Future<String> uploadVerificationDocument(String userId, List<int> bytes, String fileName) async {
    return uploadFile('verification_docs/$userId/$fileName', bytes);
  }

  @override
  Future<void> deleteFile(String path) async {
    await _client.storage.from(_bucketName).remove([path]);
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return _client.storage.from(_bucketName).getPublicUrl(path);
  }
}
