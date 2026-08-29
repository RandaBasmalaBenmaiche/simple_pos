import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/cubits/mode_cubit.dart';
import 'package:simple_pos/styles/my_colors.dart';

class ModeToggle extends StatelessWidget {
  const ModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModeCubit, AppMode>(
      builder: (context, currentMode) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text("Offline", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),),
              Switch(
                value: currentMode == AppMode.online,
                onChanged: (value) {
                  context.read<ModeCubit>().setMode(value ? AppMode.online : AppMode.offline);
                },
              ),
              Text("Online", style: TextStyle(fontWeight: FontWeight.bold, color: MyColors.mainColor(context)),),
            ],
          ),
        );
      },
    );
  }
}
