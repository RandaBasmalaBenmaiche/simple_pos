import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/styles/my_colors.dart';

class CustomPOSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showReturnButton;

  const CustomPOSAppBar({
    Key? key,
    this.showReturnButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, int>(
      builder: (context, currentStoreId) {
        // Change the title depending on the store id
        final titleText = currentStoreId == 1
            ? "Kiosque Djalil Ranim"
            : "Quincaillerie Djalil Ranim";

        return AppBar(
          leading: showReturnButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              : null,
          title: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              titleText,
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: MyColors.mainColor(context),
          centerTitle: true,
          toolbarHeight: 100, // fixed height
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}
