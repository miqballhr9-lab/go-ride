import 'package:flutter/material.dart';

import 'admin/admin_shell.dart';
import 'models.dart';
import 'screens/driver/driver_home.dart';
import 'screens/login_screen.dart';
import 'screens/passenger/passenger_home.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  runApp(GoRideApp(store: AppStore()));
}

/// Store ko poori app tak pohanchata hai; state badalne pe UI rebuild hoti hai.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class GoRideApp extends StatelessWidget {
  final AppStore store;
  const GoRideApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Go Ride',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.adminLoggedIn) return const AdminShell();
    if (store.currentUser == null) return const LoginScreen();
    return store.mode == AppMode.passenger
        ? const PassengerHome()
        : const DriverHome();
  }
}
