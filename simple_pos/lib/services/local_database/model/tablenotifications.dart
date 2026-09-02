import '../dbFactory.dart';

class DNotificationTable {
  Future<int?> insertNotification({
    required int storeId,
    required String type,
    int? productId,
    String? severity,
    String? message,
    required String createdAt,
    bool isSeen = false,
  }) async {
    try {
      final db = await DBfactory.getDatabase();
      final deviceId = await DBfactory.getDeviceId();
      final id = await db.transaction((txn) async {
        final id = await DBfactory.allocateId(txn, 'notifications');
        final record = DBfactory.withSyncMetadata({
          'id': id,
          'store_id': storeId,
          'type': type,
          'product_id': productId,
          'severity': severity,
          'message': message,
          'created_at': createdAt,
          'is_seen': isSeen ? 1 : 0,
        }, deviceId: deviceId);
        await DBfactory.notificationsStore.record(id).put(txn, record);
        await DBfactory.queueUpsert(txn, table: 'notifications', record: record);
        return id;
      });
      return id;
    } catch (e) {
      print('Insert notification error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationsByStore(int storeId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.notificationsStore.find(
        db,
        finder: Finder(filter: Filter.equals('store_id', storeId)),
      );
      return snapshots
          .map((s) => Map<String, dynamic>.from(s.value))
          .toList()
        ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    } catch (e) {
      print('Get notifications error: $e');
      return [];
    }
  }

  Future<bool> markAsSeen(int notificationId) async {
    try {
      final db = await DBfactory.getDatabase();
      return await db.transaction((txn) async {
        final existing = await DBfactory.notificationsStore.record(notificationId).get(txn);
        if (existing == null) return false;

        final updated = DBfactory.withSyncMetadata(
          {
            ...existing,
            'is_seen': 1,
          },
          syncId: existing['sync_id']?.toString(),
          deviceId: existing['device_id']?.toString(),
        );
        await DBfactory.notificationsStore.record(notificationId).put(txn, updated);
        await DBfactory.queueUpsert(txn, table: 'notifications', record: updated);
        return true;
      });
    } catch (e) {
      print('Mark seen error: $e');
      return false;
    }
  }

  Future<String?> getLastNotificationSeverity(int productId) async {
    try {
      final db = await DBfactory.getDatabase();
      final snapshots = await DBfactory.notificationsStore.find(
        db,
        finder: Finder(filter: Filter.equals('product_id', productId)),
      );
      if (snapshots.isEmpty) return null;
      // Last notification created (highest ID)
      final last = snapshots.last.value;
      return last['severity']?.toString();
    } catch (e) {
      print('Get last severity error: $e');
      return null;
    }
  }
}
