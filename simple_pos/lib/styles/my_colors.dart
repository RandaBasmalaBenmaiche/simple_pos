import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';

class MyColors {
  MyColors._(); // private constructor to prevent instantiation

  static Color mainColor(BuildContext context) {
    final storeId = context.watch<StoreCubit>().state;
    switch (storeId) {
      case 1:
        return const Color(0XFF6C3BAA); // original main color
      case 2:
        return const Color(0XFF00AA00); // example store 2 color
      case 3:
        return const Color(0XFFFF6600); // example store 3 color
      default:
        return const Color(0XFF6C3BAA);
    }
  }

  static Color secondColor(BuildContext context) {
    final storeId = context.watch<StoreCubit>().state;
    switch (storeId) {
      case 1:
        return const Color.fromARGB(255, 221, 195, 255); // original second color
      case 2:
        return const Color.fromARGB(255, 200, 255, 200); // example store 2 color
      case 3:
        return const Color.fromARGB(255, 255, 220, 180); // example store 3 color
      default:
        return const Color.fromARGB(255, 221, 195, 255);
    }
  }
}


