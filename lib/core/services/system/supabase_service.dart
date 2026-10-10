import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The app's Supabase client. Read it through this provider (not
/// `Supabase.instance`), so tests can override it with a fake (ARCH-07).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// The public client key. The old "anon" key and the newer
  /// `sb_publishable_...` key both work here.
  static String get publishableKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
