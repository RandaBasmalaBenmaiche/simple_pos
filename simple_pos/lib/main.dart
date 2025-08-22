import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:simple_pos/pages/landing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for desktop / non-mobile platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Landing(),
    );
  }
}

