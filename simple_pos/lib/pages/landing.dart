import 'package:flutter/material.dart';
import 'package:simple_pos/components/button.dart';
import 'package:simple_pos/components/dialog.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/pages/stock.dart';
import 'package:simple_pos/pages/vendre.dart';

class Landing extends StatelessWidget {
  const Landing({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: false),
      body: SizedBox(
      width: double.infinity,  
      height: double.infinity, 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                MyIconButton(
                  onPressed: () {
                    NumberInputDialog.show(
                      context: context,
                      title: "ادخل الكود الخاص بالسلعة",
                      onSubmit: (_) {
                      },
                    );
                  },
                  imagePath: "assets/icons/price.png",
                  text: "الثمن",
                ),


            
            
            MyIconButton(onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context) => POSPage()),);
}, imagePath: "assets/icons/sell.png", text: "بيع",),
              ],),
            ),
            Flexible(child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [MyIconButton(onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context) => POSPageStock()),);}, imagePath: "assets/icons/stock.png", text: "المخزن",),],
            )),
          ],
        ),
      ),
    );
  }
}