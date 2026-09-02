// store_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

class StoreCubit extends Cubit<int> {
  StoreCubit() : super(1) {
    _loadStoredStore();
  }

  Future<void> _loadStoredStore() async {
    final storedStore = await DBfactory.getMetaValue('selected_store_id');
    if (storedStore != null && storedStore is int) {
      emit(storedStore);
    }
  }

  void switchStore(int storeId) {
    emit(storeId);
    DBfactory.setMetaValue('selected_store_id', storeId);
  }
}
