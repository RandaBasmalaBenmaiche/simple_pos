import 'package:flutter/material.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/pages/landing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/local_database/dbFactory.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBfactory.getDatabase();

  runApp(
    BlocProvider(
      create: (_) => StoreCubit(),
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
      navigatorObservers: [routeObserver], // ✅ added
      home: const Landing(),
    );
  }
}