import 'package:flutter/material.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/cubits/mode_cubit.dart';
import 'package:simple_pos/services/cubits/app_initialization_cubit.dart';
import 'package:simple_pos/pages/landing.dart';
import 'package:simple_pos/pages/login.dart';
import 'package:simple_pos/pages/reset_password.dart';
import 'package:simple_pos/pages/initialization_page.dart';
import 'package:simple_pos/services/auth/simple_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StoreCubit()),
        BlocProvider(create: (_) => ModeCubit()),
        BlocProvider(create: (_) => AppInitializationCubit()..initialize()),
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
      home: BlocBuilder<AppInitializationCubit, InitializationState>(
        builder: (context, state) {
          if (state is InitializationSuccess) {
            return const AuthGate();
          }
          return const InitializationPage();
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
