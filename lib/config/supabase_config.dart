class SupabaseConfig {
  static const String url = 'https://xmtunakzkbbjqrnawwjy.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtdHVuYWt6a2JianFybmF3d2p5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NzE5NDIsImV4cCI6MjA4MTM0Nzk0Mn0.6Idqv5OgBFjxD01LTuNFUoaoccbZipoScfY72YQGB-8';

  static void assertValid() {
    try {
      assert(
        url.startsWith('https://') &&
            url.endsWith('.supabase.co') &&
            anonKey.isNotEmpty,
        'Invalid Supabase config. Check URL and anonKey.',
      );
    } catch (_) {
      rethrow;
    }
  }
}
