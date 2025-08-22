import 'package:flutter/material.dart';
import 'package:simple_pos/styles/my_colors.dart';


class MyIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String imagePath;
  final String text;

  const MyIconButton({
    Key? key,
    required this.onPressed,
    required this.imagePath,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(MyColors.secondColor(context)),
        fixedSize: MaterialStateProperty.all(
          Size(
            MediaQuery.of(context).size.width * 0.25,
            MediaQuery.of(context).size.height * 0.25,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 50,
            width: 50,
            child: Image.asset(imagePath),
          ),
          Text(
            text,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
