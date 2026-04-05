import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_row_mapper.dart';

class WebPosRepository {
  WebPosRepository._();

  static final WebPosRepository instance = WebPosRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getStockByStore(int? storeId) async {
    final response = await _client
        .from('stock')
        .select()
        .eq('store_id', storeId ?? 0)
        .order('local_id', ascending: false);

    return (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              'stock',
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> getStockByCode(String codeBar, int? storeId) async {
    final response = await _client
        .from('stock')
        .select()
        .eq('store_id', storeId ?? 0)
        .eq('productcodebar', codeBar)
        .limit(1);
    if ((response as List).isEmpty) return null;
    return SupabaseRowMapper.fromRemote(
      'stock',
      Map<String, dynamic>.from(response.first as Map),
    );
  }

  Future<Map<String, dynamic>?> getStockByName(String name, int? storeId) async {
    final response = await _client
        .from('stock')
        .select()
        .eq('store_id', storeId ?? 0)
        .ilike('productname', name)
        .limit(1);
    if ((response as List).isEmpty) return null;
    return SupabaseRowMapper.fromRemote(
      'stock',
      Map<String, dynamic>.from(response.first as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getCustomers(int storeId) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .order('local_id', ascending: false);
    return (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              'customers',
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query, int storeId) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .ilike('name', '%$query%')
        .order('local_id', ascending: false);
    return (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              'customers',
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('local_id', id)
        .limit(1);
    if ((response as List).isEmpty) return null;
    return SupabaseRowMapper.fromRemote(
      'customers',
      Map<String, dynamic>.from(response.first as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getInvoices(int storeId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('store_id', storeId)
        .order('date', ascending: false);
    return (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              'invoices',
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> getInvoiceById(int invoiceId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('local_id', invoiceId)
        .limit(1);
    if ((response as List).isEmpty) return null;
    return SupabaseRowMapper.fromRemote(
      'invoices',
      Map<String, dynamic>.from(response.first as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getInvoiceItemsByInvoiceId(int invoiceId) async {
    final response = await _client
        .from('invoice_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('local_id');
    return (response as List)
        .map((row) => SupabaseRowMapper.fromRemote(
              'invoice_items',
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }
}
