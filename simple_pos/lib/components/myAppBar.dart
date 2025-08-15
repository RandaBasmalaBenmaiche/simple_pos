import 'package:flutter/material.dart';
import 'package:simple_pos/styles/my_colors.dart';


class CustomPOSAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showReturnButton;

  const CustomPOSAppBar({
    Key? key,
    this.showReturnButton = true, // Default: show the return button
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showReturnButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null,
      title: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Kiosque Djalil Ranim",
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: MyColors.mainColor,
      centerTitle: true,
      toolbarHeight: 150,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(150);
}
