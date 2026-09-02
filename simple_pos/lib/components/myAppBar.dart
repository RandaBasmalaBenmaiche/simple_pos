import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_pos/services/auth/simple_auth_service.dart';
import 'package:simple_pos/services/cubits/storeCubit.dart';
import 'package:simple_pos/services/cubits/notification_cubit.dart';
import 'package:simple_pos/services/supabase/web_realtime_service.dart';
import 'package:simple_pos/styles/my_colors.dart';
import 'package:intl/intl.dart';

class CustomPOSAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showReturnButton;
  final bool showTitle;

  const CustomPOSAppBar({
    Key? key,
    this.showReturnButton = true,
    this.showTitle = true,
  }) : super(key: key);

  @override
  _CustomPOSAppBarState createState() => _CustomPOSAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(showTitle ? 100 : 60);
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
    return BlocListener<StoreCubit, int>(
      listener: (context, currentStoreId) {
        context.read<NotificationCubit>().refreshNotifications(currentStoreId);
      },
      child: BlocBuilder<StoreCubit, int>(
        builder: (context, currentStoreId) {
          final titleText = currentStoreId == 1
              ? "Kiosque Djallil Ranim"
              : "Quincaillerie Djallil Ranim";

          return AppBar(
            leading: widget.showReturnButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: widget.showTitle
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
            backgroundColor: MyColors.mainColor(context),
            centerTitle: true,
            toolbarHeight: widget.showTitle ? 100 : 60,
            actions: [
              BlocBuilder<NotificationCubit, NotificationState>(
                builder: (context, state) {
                  final notifications = state.notifications;
                  final unseenCount = notifications.where((n) => !n.isSeen).length;
                  print('myAppBar: Building notification badge. Unseen count: $unseenCount');
                  return PopupMenuButton<POSNotification>(
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications, color: Colors.white, size: 35),
                        if (unseenCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                '$unseenCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onSelected: (notification) {
                      if (notification == null) return;
                      print('myAppBar: [DEBUG] Notification selected ID: ${notification.id}');
                      context.read<NotificationCubit>().markAsSeen(notification.id);
                      setState(() {});
                    },
                    itemBuilder: (context) {
                      if (notifications.isEmpty) {
                        return [
                          const PopupMenuItem<POSNotification>(
                            value: null,
                            child: Text("لا توجد تنبيهات"),
                          ),
                        ];
                      }
                      return notifications.map((n) {
                        final date = DateFormat('yyyy-MM-dd HH:mm').format(n.createdAt);
                        String title = "";
                        Widget leadingIcon = const SizedBox.shrink();

                        if (n is StockNotification) {
                          title = "${n.productName} (الكمية: ${n.currentQuantity})";
                          leadingIcon = Icon(
                            Icons.circle,
                            color: n.severity == NotificationSeverity.red
                                ? Colors.red
                                : Colors.yellow,
                            size: 12,
                          );
                        } else if (n is GeneralNotification) {
                          title = n.message;
                          leadingIcon = const Icon(
                            Icons.info,
                            color: Colors.blue,
                            size: 12,
                          );
                        }

                        return PopupMenuItem<POSNotification>(
                          value: n,
                          child: InkWell(
                            onTap: () {
                              print('myAppBar: Item InkWell tapped for ID: ${n.id}');
                              context.read<NotificationCubit>().markAsSeen(n.id);
                            },
                            child: SizedBox(
                              width: 300,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      leadingIcon,
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: n.isSeen ? FontWeight.normal : FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (n is StockNotification)
                                        Text(
                                          "الحد: ${n.minStock}",
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    date,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList();
                    },
                  );
                },
              ),
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
      ),
    );
  }
}
