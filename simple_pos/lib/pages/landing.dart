import 'package:flutter/material.dart';
import 'package:simple_pos/components/myAppBar.dart';
import 'package:simple_pos/components/storeSwitchToggle.dart';
import 'package:simple_pos/pages/customers.dart';
import 'package:simple_pos/pages/history.dart';
import 'package:simple_pos/pages/overview.dart';
import 'package:simple_pos/pages/stock.dart';
import 'package:simple_pos/pages/vendre.dart';
import 'package:simple_pos/components/landingIconButton.dart';
import 'package:simple_pos/components/priceDialog.dart';

class Landing extends StatelessWidget {
  const Landing({super.key});

  Future<void> _showPasswordDialog(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    final FocusNode passwordFocusNode = FocusNode();
    const String correctPassword = "18071970";

    void checkPassword() {
      if (passwordController.text == correctPassword) {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const POSPageOverview()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("كلمة المرور غير صحيحة")),
        );
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        // ✅ Request focus after dialog is built
        Future.microtask(() => passwordFocusNode.requestFocus());

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "أدخل كلمة المرور",
            textAlign: TextAlign.center,
          ),
          content: TextField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "كلمة المرور",
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => checkPassword(), // ✅ Press Enter = "دخول"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: checkPassword,
              child: const Text("دخول"),
            ),
          ],
        );
      },
    );

    // ✅ Clear password after dialog closes
    passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomPOSAppBar(showReturnButton: false),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            const StoreToggle(),
            Flexible(
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
                            PriceDialog.show(
                              context: context,
                              title: "ادخل الكود الخاص بالسلعة",
                              onSubmit: (_) {},
                            );
                          },
                          imagePath: "assets/icons/price.png",
                          text: "الثمن",
                        ),
                        MyIconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const POSPage()),
                            );
                          },
                          imagePath: "assets/icons/sell.png",
                          text: "بيع",
                        ),
                        MyIconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const POSPageCustomers()),
                            );
                          },
                          imagePath: "assets/icons/customers.png",
                          text: "الزبائن",
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MyIconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const POSPageStock()),
                            );
                          },
                          imagePath: "assets/icons/stock.png",
                          text: "المخزن",
                        ),
                        MyIconButton(
                          onPressed: () => _showPasswordDialog(context),
                          imagePath: "assets/icons/locked.png",
                          text: "الفضاء الخاص",
                        ),
                        MyIconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const POSPageHistorique()),
                            );
                          },
                          imagePath: "assets/icons/history.png",
                          text: "تاريخ المبيعات",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
