import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/local_database/model/tablestock.dart';
import 'package:simple_pos/services/local_database/model/tablealiases.dart';
import 'package:simple_pos/services/local_database/model/tablenotifications.dart';
import 'package:simple_pos/services/cubits/notification_cubit.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

enum ImportStatus { idle, importing, success, failure }

class ImportState {
  final ImportStatus status;
  final String? errorMessage;
  final int? importedCount;

  ImportState({
    this.status = ImportStatus.idle,
    this.errorMessage,
    this.importedCount,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? errorMessage,
    int? importedCount,
  }) {
    return ImportState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      importedCount: importedCount ?? this.importedCount,
    );
  }
}

class ImportCubit extends Cubit<ImportState> {
  ImportCubit() : super(ImportState());

  Future<void> importProducts({
    required List<Map<String, dynamic>> matchingData,
    required int storeId,
    required NotificationCubit notificationCubit,
  }) async {
    emit(state.copyWith(status: ImportStatus.importing));

    final stockTable = DStockTable();
    final aliasTable = DAliasesTable();
    int successCount = 0;
    bool overallSuccess = true;

    try {
      for (var item in matchingData) {
        final productId = item['matchedProductId'] as int?;
        final extractedName = (item['nameController'] as dynamic).text; // Handle different controller types if needed
        final qty = double.tryParse((item['qtyController'] as dynamic).text) ?? 0;

        if (productId != null) {
          final product = await stockTable.getProductById(productId);
          if (product != null) {
            final currentQty = double.tryParse(product['productQuantity']?.toString() ?? '0') ?? 0;
            final newQty = (currentQty + qty).toString();

            await stockTable.updateProductById(
              id: productId,
              newQuantity: newQty,
            );

            final originalName = product['productName'] as String;
            if (extractedName.trim().toLowerCase() != originalName.trim().toLowerCase()) {
              await aliasTable.saveAlias(
                productId: productId,
                productSyncId: product['sync_id']?.toString() ?? '',
                aliasName: extractedName,
                storeId: storeId,
                storeSyncId: (await DBfactory.storesStore.record(storeId).get(await DBfactory.getDatabase()))?['sync_id']?.toString() ?? '',
              );
            }
            successCount++;
          } else {
            overallSuccess = false;
          }
        } else {
          final newId = await stockTable.insertProduct(
            storeId: storeId,
            name: extractedName,
            quantity: qty.toString(),
          );
          if (newId == null) {
            overallSuccess = false;
          } else {
            successCount++;
          }
        }
      }

      if (overallSuccess) {
        // Add system notification
        await DNotificationTable().insertNotification(
          storeId: storeId,
          type: 'system',
          message: 'تم استيراد $successCount منتج بنجاح',
          createdAt: DBfactory.nowIso(),
        );

        // Refresh notifications in the app
        await notificationCubit.refreshNotifications(storeId);

        emit(state.copyWith(status: ImportStatus.success, importedCount: successCount));
      } else {
        emit(state.copyWith(status: ImportStatus.failure, errorMessage: 'Some products failed to import'));
      }
    } catch (e) {
      print('Import error: $e');
      emit(state.copyWith(status: ImportStatus.failure, errorMessage: e.toString()));
    }
  }
}
