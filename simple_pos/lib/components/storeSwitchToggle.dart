import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/styles/my_colors.dart';

class StoreToggle extends StatelessWidget {
  const StoreToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, int>(
      builder: (context, currentStoreId) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text("kiosque", style: TextStyle(fontWeight: FontWeight.bold, color: MyColors.mainColor(context)),),
              Switch(
                value: currentStoreId == 2,
                onChanged: (value) {
                  context.read<StoreCubit>().switchStore(value ? 2 : 1);
                },
              ),
              Text("quincaillerie", style: TextStyle(fontWeight: FontWeight.bold, color: MyColors.mainColor(context)),),
            ],
          ),
        );
      },
    );
  }
}
