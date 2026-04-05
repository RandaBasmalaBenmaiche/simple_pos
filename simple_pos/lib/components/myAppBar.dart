import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/auth/simple_auth_service.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:intl/intl.dart';

class CustomPOSAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showReturnButton;

  const CustomPOSAppBar({
    Key? key,
    this.showReturnButton = true,
  }) : super(key: key);

  @override
  _CustomPOSAppBarState createState() => _CustomPOSAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

class _CustomPOSAppBarState extends State<CustomPOSAppBar> {
  late Timer _timer;
  DateTime _currentDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, int>(
      builder: (context, currentStoreId) {
        final titleText = currentStoreId == 1
            ? "Kiosque Djalil Ranim"
            : "Quincaillerie Djalil Ranim";

        return AppBar(
          leading: widget.showReturnButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
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
          toolbarHeight: 100,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await WebRealtimeService.instance.dispose();
                await SimpleAuthService.instance.logout();
                if (!mounted) {
                  return;
                }
                Navigator.of(context, rootNavigator: true)
                    .popUntil((route) => route.isFirst);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  DateFormat('yyyy-MM-dd – HH:mm:ss').format(_currentDateTime),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
