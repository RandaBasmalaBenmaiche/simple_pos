import 'dart:async';

import 'package:flutter/material.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/cubits/mode_cubit.dart';
import 'package:simple_pos/pages/landing.dart';
import 'package:simple_pos/pages/login.dart';
import 'package:simple_pos/pages/reset_password.dart';
import 'package:simple_pos/services/auth/simple_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';
import 'package:simple_pos/services/supabase/supabase_project_config.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/services/sync/sync_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseProjectConfig.initialize();
  await DBfactory.getDatabase();
  await SimpleAuthService.instance.initialize();
  await SyncService.instance.initialize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StoreCubit()),
        BlocProvider(create: (_) => ModeCubit()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  void _onAuthChanged() {
    if (SimpleAuthService.instance.isLoggedIn.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(WebRealtimeService.instance.initialize());
        unawaited(SyncService.instance.triggerSync());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SimpleAuthService.instance.isLoggedIn.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    SimpleAuthService.instance.isLoggedIn.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SimpleAuthService.instance.isLoggedIn,
      builder: (context, isLoggedIn, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SimpleAuthService.instance.isPasswordRecovery,
          builder: (context, isPasswordRecovery, __) {
            if (isPasswordRecovery) {
              return const ResetPasswordPage();
            }
            if (isLoggedIn) {
              return const Landing();
            }
            return const LoginPage();
          },
        );
      },
    );
  }
}
