import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/sync_service.dart';
import 'web_runtime.dart';

class WebRealtimeService {
  WebRealtimeService._();

  static final WebRealtimeService instance = WebRealtimeService._();

  final StreamController<Set<String>> _changes =
      StreamController<Set<String>>.broadcast();
  final List<RealtimeChannel> _channels = [];
  bool _initialized = false;

  Stream<Set<String>> get changes => _changes.stream;

  Future<void> initialize() async {
    if (_initialized ||
        !useSupabaseWeb ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }

    _initialized = true;
    const tables = [
      'stores',
      'stock',
      'customers',
      'debt_payments',
      'invoices',
      'invoice_items',
    ];

    for (final table in tables) {
      final channel = Supabase.instance.client.channel('public:$table');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          unawaited(_handleRemoteChange(table));
        },
      );
      channel.subscribe();
      _channels.add(channel);
    }
  }

  Future<void> _handleRemoteChange(String table) async {
    try {
      await SyncService.instance.triggerSync();
    } finally {
          _changes.add({table});
    }
  }

  Future<void> dispose() async {
    for (final channel in _channels) {
      await Supabase.instance.client.removeChannel(channel);
    }
    _channels.clear();
    _initialized = false;
  }
}
