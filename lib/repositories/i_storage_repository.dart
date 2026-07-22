/// Abstract repository interface for file storage operations.
/// Implementations: [FirebaseStorageRepository], [SupabaseStorageRepository]

abstract class IStorageRepository {
  /// Upload a file (returns download URL or path)
  Future<String> uploadFile(String path, List<int> bytes, {String? contentType});

  /// Upload a profile photo
  Future<String> uploadProfilePhoto(String userId, List<int> bytes);

  /// Upload a verification document
  Future<String> uploadVerificationDocument(String userId, List<int> bytes, String fileName);

  /// Delete a file
  Future<void> deleteFile(String path);

  /// Get download URL for a file
  Future<String> getDownloadUrl(String path);
}
