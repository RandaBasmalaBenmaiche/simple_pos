import 'package:bloc/bloc.dart';
import 'package:simple_pos/services/local_database/model/tablenotifications.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';

enum NotificationSeverity { yellow, red, none }
enum NotificationType { stock, system }

abstract class POSNotification {
  final int id;
  final DateTime createdAt;
  final bool isSeen;

  POSNotification({
    required this.id,
    required this.createdAt,
    required this.isSeen,
  });

  POSNotification copyWith({bool? isSeen});
}

class StockNotification extends POSNotification {
  final String productName;
  final double currentQuantity;
  final int minStock;
  final NotificationSeverity severity;

  StockNotification({
    required super.id,
    required this.productName,
    required this.currentQuantity,
    required this.minStock,
    required this.severity,
    required super.createdAt,
    required super.isSeen,
  });

  @override
  StockNotification copyWith({bool? isSeen}) {
    return StockNotification(
      id: id,
      productName: productName,
      currentQuantity: currentQuantity,
      minStock: minStock,
      severity: severity,
      createdAt: createdAt,
      isSeen: isSeen ?? this.isSeen,
    );
  }
}

class GeneralNotification extends POSNotification {
  final String message;
  final NotificationType type;

  GeneralNotification({
    required super.id,
    required this.message,
    required this.type,
    required super.createdAt,
    required super.isSeen,
  });

  @override
  GeneralNotification copyWith({bool? isSeen}) {
    return GeneralNotification(
      id: id,
      message: message,
      type: type,
      createdAt: createdAt,
      isSeen: isSeen ?? this.isSeen,
    );
  }
}

class NotificationState {
  final List<POSNotification> notifications;
  final bool isLoading;

  NotificationState({
    required this.notifications,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<POSNotification>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(NotificationState(notifications: []));

  Future<void> refreshNotifications(int storeId) async {
    emit(state.copyWith(isLoading: true));
    try {
      final notificationTable = DNotificationTable();
      final productsTable = DStockTable();
      final rawNotifications = await notificationTable.getNotificationsByStore(storeId);

      final notifications = <POSNotification>[];

      for (final n in rawNotifications) {
        final type = n['type']?.toString() == 'system' ? NotificationType.system : NotificationType.stock;

        if (type == NotificationType.stock) {
          final productId = n['product_id'] as int?;
          if (productId == null) continue;
          final product = await productsTable.getProductById(productId);

          notifications.add(StockNotification(
            id: n['id'] as int,
            productName: product?['productName'] ?? 'Unknown',
            currentQuantity: double.tryParse(product?['productQuantity']?.toString() ?? '0') ?? 0,
            minStock: n['min_stock'] as int? ?? 0,
            severity: n['severity'] == 'red' ? NotificationSeverity.red : NotificationSeverity.yellow,
            createdAt: DateTime.parse(n['created_at'] as String),
            isSeen: (n['is_seen'] as int? ?? 0) == 1,
          ));
        } else {
          notifications.add(GeneralNotification(
            id: n['id'] as int,
            message: n['message']?.toString() ?? 'System notification',
            type: NotificationType.system,
            createdAt: DateTime.parse(n['created_at'] as String),
            isSeen: (n['is_seen'] as int? ?? 0) == 1,
          ));
        }
      }

      emit(NotificationState(notifications: notifications, isLoading: false));
    } catch (e) {
      print('Error refreshing notifications: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> markAsSeen(int notificationId) async {
    print('NotificationCubit: markAsSeen called for ID: $notificationId');

    final updatedList = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isSeen: true);
      }
      return n;
    }).toList();

    emit(NotificationState(notifications: updatedList, isLoading: state.isLoading));

    try {
      final notificationTable = DNotificationTable();
      await notificationTable.markAsSeen(notificationId);
    } catch (e) {
      print('Error persisting markAsSeen: $e');
    }
  }
}
