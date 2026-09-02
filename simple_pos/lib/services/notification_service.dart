import 'package:simple_pos/services/local_database/model/tablenotifications.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final DNotificationTable _notificationTable = DNotificationTable();

  Future<void> checkAndCreateNotification({
    required int storeId,
    required int productId,
    required double currentQty,
    required int minStock,
  }) async {
    String? currentSeverity;
    if (currentQty == 0) {
      currentSeverity = 'red';
    } else if (currentQty < minStock) {
      currentSeverity = 'yellow';
    } else {
      currentSeverity = 'none';
    }

    // We only create a notification if we transition to a "warning" state (yellow or red)
    if (currentSeverity == 'none') return;

    final lastSeverity = await _notificationTable.getLastNotificationSeverity(productId);

    // Create notification if:
    // 1. No previous notification exists
    // 2. Status has changed (e.g., Yellow -> Red or Red -> Yellow)
    if (lastSeverity == null || lastSeverity != currentSeverity) {
      await _notificationTable.insertNotification(
        storeId: storeId,
        type: 'stock',
        productId: productId,
        severity: currentSeverity,
        createdAt: DBfactory.nowIso(),
      );
    }
  }
}
