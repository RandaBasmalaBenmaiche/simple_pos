import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProjectConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String syncIntervalSeconds = String.fromEnvironment(
    'SYNC_INTERVAL_SECONDS',
    defaultValue: '20',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static Duration get syncInterval {
    final seconds = int.tryParse(syncIntervalSeconds) ?? 20;
    return Duration(seconds: seconds < 5 ? 5 : seconds);
  }

  static Future<void> initialize() async {
    if (!isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
