// store_cubit.dart
import 'package:bloc/bloc.dart';

class StoreCubit extends Cubit<int> {
  StoreCubit() : super(1); // default store ID = 1

  void switchStore(int storeId) {
    emit(storeId);
  }
}
