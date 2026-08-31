import 'package:flutter/material.dart';
import 'package:simple_pos/styles/my_colors.dart';


class MyIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String imagePath;
  final String text;
  final bool showText;

  const MyIconButton({
    Key? key,
    required this.onPressed,
    required this.imagePath,
    required this.text,
    this.showText = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(MyColors.secondColor(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: Image.asset(imagePath),
          ),
          if (showText)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
