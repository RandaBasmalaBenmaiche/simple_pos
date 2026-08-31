import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/supabase/supabase_project_config.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/auth/simple_auth_service.dart';
import 'package:simple_pos/services/sync/sync_service.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';

abstract class InitializationState {}

class InitializationInitial extends InitializationState {}

class InitializationLoading extends InitializationState {
  final String step;
  InitializationLoading(this.step);
}

class InitializationSuccess extends InitializationState {}

class InitializationFailure extends InitializationState {
  final String error;
  InitializationFailure(this.error);
}

class AppInitializationCubit extends Cubit<InitializationState> {
  AppInitializationCubit() : super(InitializationInitial());

  Future<void> initialize() async {
    try {
      emit(InitializationLoading('Initializing Supabase...'));
      await _withTimeout(SupabaseProjectConfig.initialize());

      emit(InitializationLoading('Initializing Local Database...'));
      await _withTimeout(DBfactory.getDatabase());

      emit(InitializationLoading('Initializing Auth Service...'));
      await _withTimeout(SimpleAuthService.instance.initialize());

      emit(InitializationLoading('Initializing Sync Service...'));
      await _withTimeout(SyncService.instance.initialize());

      emit(InitializationSuccess());
    } catch (e) {
      emit(InitializationFailure(e.toString()));
    }
  }

  Future<T> _withTimeout<T>(Future<T> future, {Duration timeout = const Duration(seconds: 15)}) async {
    return await future.timeout(timeout, onTimeout: () {
      throw TimeoutException('Operation timed out after ${timeout.inSeconds} seconds');
    });
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
