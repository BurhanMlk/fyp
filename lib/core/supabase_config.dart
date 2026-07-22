/// Supabase Configuration for Blood Bridge
/// ========================================
/// To connect your app to Supabase (PostgreSQL):
///
/// 1. Create a project at https://supabase.com
/// 2. Go to Settings → API in your Supabase dashboard
/// 3. Copy the "Project URL" and "anon public" key below
/// 4. Run the schema: database/supabase_schema.sql in Supabase SQL Editor
///
/// Then just hot-reload the app — data will go to PostgreSQL!

class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL
  /// Get this from: Supabase Dashboard → Settings → API → Project URL
  static const String url = 'https://xhrmntouhykreebonsio.supabase.co';

  /// Your Supabase anonymous public key
  /// Get this from: Supabase Dashboard → Settings → API → Publishable key
  static const String anonKey = 'sb_publishable_mvuO2iRrr7AYPHpty81eIw_1wY4Tru_';

  /// Database schema name (default: 'public')
  static const String schemaName = 'public';

  /// Storage bucket name for file uploads
  static const String storageBucket = 'blood-bridge-files';

  /// Whether Supabase is configured (has real credentials)
  static bool get isConfigured =>
      url.isNotEmpty &&
      !url.contains('YOUR_PROJECT_ID') &&
      anonKey.isNotEmpty &&
      !anonKey.contains('YOUR_ANON_KEY');
}
