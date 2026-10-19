import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'offers_view.dart';
import 'passenger_ride_view.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  Place? from = AppStore.places.first;
  Place? to;
  final fareCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    fareCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  int? get _suggested =>
      (from != null && to != null) ? AppStore.suggestedFare(from!, to!) : null;

  void _pickTo() async {
    final p = await pickPlace(context, 'Kahan jana hai?', exclude: from);
    if (p == null) return;
    setState(() {
      to = p;
      fareCtrl.text = '$_suggested';
    });
  }

  void _pickFrom() async {
    final p = await pickPlace(context, 'Pickup kahan se?', exclude: to);
    if (p == null) return;
    setState(() {
      from = p;
      if (_suggested != null) fareCtrl.text = '$_suggested';
    });
  }

  void _findDriver() {
    final fare = int.tryParse(fareCtrl.text.trim());
    setState(() => error = null);
    if (from == null || to == null) {
      setState(() => error = 'Pickup aur manzil dono chunein');
      return;
    }
    // inDrive ki tarah kam se kam kiraye ki had.
    final minFare = (_suggested! * 0.6).round();
    if (fare == null || fare < minFare) {
      setState(() => error = 'Kam se kam kiraya ${pkr(minFare)} hai');
      return;
    }
    StoreScope.of(context).createRequest(from!, to!, fare, commentCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ride = store.passengerRide;
    if (ride != null) {
      return ride.status == RideStatus.searching
          ? OffersView(ride: ride)
          : PassengerRideView(ride: ride);
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: RideMap(from: from, to: to)),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Builder(
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: FloatingActionButton.small(
                    heroTag: 'menu',
                    backgroundColor: Colors.white,
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    child: const Icon(Icons.menu),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _requestCard(),
          ),
        ],
      ),
    );
  }

  Widget _requestCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 16, color: Colors.black12)],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tile(Icons.circle, AppColors.brand, from?.name ?? 'Pickup', _pickFrom),
            const SizedBox(height: 8),
            _tile(Icons.circle, AppColors.dark, to?.name ?? 'Kahan jana hai?', _pickTo,
                placeholder: to == null),
            const SizedBox(height: 8),
            TextField(
              controller: fareCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text('Rs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
                hintText: 'Apna kiraya batayein',
                helperText: _suggested == null ? null : 'Mashwara kiraya: ${pkr(_suggested!)}',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.chat_bubble_outline),
                hintText: 'Comment (optional)',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: _findDriver, child: const Text('Driver dhoondein')),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, Color color, String text, VoidCallback onTap, {bool placeholder = false}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 16, color: placeholder ? AppColors.muted : AppColors.dark)),
            ),
          ]),
        ),
      ),
    );
  }
}
