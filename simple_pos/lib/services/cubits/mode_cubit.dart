import 'package:bloc/bloc.dart';

enum AppMode { online, offline }

class ModeCubit extends Cubit<AppMode> {
  ModeCubit() : super(AppMode.online); // default mode = online

  void setMode(AppMode mode) {
    emit(mode);
  }

  void toggleMode() {
    if (state == AppMode.online) {
      emit(AppMode.offline);
    } else {
      emit(AppMode.online);
    }
  }
}
