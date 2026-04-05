class SupabaseRowMapper {
  static Map<String, dynamic> toRemote(
    String table,
    Map<String, dynamic> local,
  ) {
    final normalized = Map<String, dynamic>.from(local)..remove('id');

    switch (table) {
      case 'stock':
        return {
          ...normalized,
          'productname': normalized['productName'],
          'productprice': normalized['productPrice'],
          'productbuyingprice': normalized['productBuyingPrice'],
          'productcodebar': normalized['productCodeBar'],
          'productquantity': normalized['productQuantity'],
        }..removeWhere((key, _) => _stockCamelKeys.contains(key));
      case 'invoice_items':
        return {
          ...normalized,
          'invoice_sync_id':
              normalized['invoice_sync_id'] ?? normalized['invoice_sync_id'],
          'productcodebar': normalized['productCodeBar'],
          'productname': normalized['productName'],
          'totalprice': normalized['totalPrice'],
        }..removeWhere((key, _) => _invoiceItemCamelKeys.contains(key));
      default:
        return normalized;
    }
  }

  static Map<String, dynamic> fromRemote(
    String table,
    Map<String, dynamic> remote,
  ) {
    switch (table) {
      case 'stock':
        return {
          ...remote,
          'productName': remote['productName'] ?? remote['productname'],
          'productPrice': remote['productPrice'] ?? remote['productprice'],
          'productBuyingPrice':
              remote['productBuyingPrice'] ?? remote['productbuyingprice'],
          'productCodeBar':
              remote['productCodeBar'] ?? remote['productcodebar'],
          'productQuantity':
              remote['productQuantity'] ?? remote['productquantity'],
        };
      case 'invoice_items':
        return {
          ...remote,
          'productCodeBar':
              remote['productCodeBar'] ?? remote['productcodebar'],
          'productName': remote['productName'] ?? remote['productname'],
          'totalPrice': remote['totalPrice'] ?? remote['totalprice'],
        };
      default:
        return remote;
    }
  }

  static const _stockCamelKeys = {
    'productName',
    'productPrice',
    'productBuyingPrice',
    'productCodeBar',
    'productQuantity',
  };

  static const _invoiceItemCamelKeys = {
    'productCodeBar',
    'productName',
    'totalPrice',
  };
}
