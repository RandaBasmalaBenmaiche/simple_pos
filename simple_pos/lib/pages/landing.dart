import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/pages/history.dart';
import 'package:simple_pos/pages/stock.dart';
import 'package:simple_pos/pages/vendre.dart';
import 'package:simple_pos/components/landingIconButton.dart';
import 'package:simple_pos/components/priceDialog.dart';



class Landing extends StatelessWidget {
  const Landing({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      //the custom app Bar
      appBar: const CustomPOSAppBar(showReturnButton: false),


      body: SizedBox(
      width: double.infinity,  
      height: double.infinity, 

      //The three Icon buttons

        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                


                //Price Icon button
                MyIconButton(
                  onPressed: () {
                    PriceDialog.show(
                      context: context,
                      title: "ادخل الكود الخاص بالسلعة",
                      onSubmit: (_) {
                      },
                    );
                  },
                  imagePath: "assets/icons/price.png",
                  text: "الثمن",
                ),


            
            //Sell Icon button
            MyIconButton(onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context) => const POSPage()),);}, imagePath: "assets/icons/sell.png", text: "بيع",),
              ],),
            ),


            Flexible(child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              //Stock Icon button
              children: [
                MyIconButton(onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context) => const POSPageStock()),);}, imagePath: "assets/icons/stock.png", text: "المخزن",),
                MyIconButton(onPressed: (){Navigator.push(context,MaterialPageRoute(builder: (context) => const POSPageHistorique()),);}, imagePath: "assets/icons/history.png", text: "تاريخ المبيعات",),
                ],
            )),
          ],
        ),
      ),
    );
  }
}