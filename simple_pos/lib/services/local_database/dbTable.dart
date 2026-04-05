import 'package:flutter/foundation.dart';

class DBBaseTable {
  var db_table = 'TABLE_NAME_MUST_OVERRIDE';

  Future<bool> insertRecord(Map<String, dynamic> data) async {
    try {
      // This is a base class - subclasses should override with specific DB logic.
      debugPrint('Insert called on base class for table: $db_table');
      return true;
    } catch (e, stacktrace) {
      debugPrint('Insert error: $e --> $stacktrace');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getRecords() async {
    try {
      // This is a base class - subclasses should override with specific DB logic.
      debugPrint('GetRecords called on base class for table: $db_table');
      return [];
    } catch (e, stacktrace) {
      debugPrint('GetRecords error: $e --> $stacktrace');
    }
    return [];
  }
}
