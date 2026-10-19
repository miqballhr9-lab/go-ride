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
  VehicleType type = VehicleType.mini;
  final fareCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    fareCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  int? _suggested(AppStore store, [VehicleType? t]) =>
      (from != null && to != null) ? store.suggestedFare(t ?? type, from!, to!) : null;

  void _refreshFare() {
    final s = _suggested(StoreScope.of(context));
    if (s != null) fareCtrl.text = '$s';
  }

  void _pickTo() async {
    final p = await pickPlace(context, 'Where to?', exclude: from);
    if (p == null) return;
    setState(() => to = p);
    _refreshFare();
  }

  void _pickFrom() async {
    final p = await pickPlace(context, 'Pickup location', exclude: to);
    if (p == null) return;
    setState(() => from = p);
    _refreshFare();
  }

  void _findDriver() {
    final store = StoreScope.of(context);
    final fare = int.tryParse(fareCtrl.text.trim());
    setState(() => error = null);
    if (from == null || to == null) {
      setState(() => error = 'Choose both pickup and destination');
      return;
    }
    final minFare = store.lowestAllowedFare(type, from!, to!);
    if (fare == null || fare < minFare) {
      setState(() => error = 'Minimum fare for this trip is ${pkr(minFare)}');
      return;
    }
    store.createRequest(type, from!, to!, fare, commentCtrl.text.trim());
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
          Positioned.fill(
            child: RideMap(
              from: from,
              to: to,
              cars: [for (final d in store.onlineDrivers) d.driver!.location!],
            ),
          ),
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
          Align(alignment: Alignment.bottomCenter, child: _requestCard(store)),
        ],
      ),
    );
  }

  Widget _requestCard(AppStore store) {
    final suggested = _suggested(store);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 16, color: Colors.black12)],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 74,
              child: Row(children: [
                for (final t in VehicleType.values) ...[
                  Expanded(child: _typeTile(store, t)),
                  if (t != VehicleType.values.last) const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            _tile(AppColors.brand, from?.name ?? 'Pickup', _pickFrom),
            const SizedBox(height: 8),
            _tile(AppColors.dark, to?.name ?? 'Where to?', _pickTo, placeholder: to == null),
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
                hintText: 'Offer your fare',
                helperText: suggested == null ? null : 'Recommended fare: ${pkr(suggested)} · Cash',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.chat_bubble_outline),
                hintText: 'Comment for driver (optional)',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            FilledButton(onPressed: _findDriver, child: const Text('Find a driver')),
          ],
        ),
      ),
    );
  }

  Widget _typeTile(AppStore store, VehicleType t) {
    final selected = t == type;
    final price = _suggested(store, t);
    return Material(
      color: selected ? AppColors.brand.withValues(alpha: 0.25) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.dark : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => type = t);
          _refreshFare();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(t == VehicleType.moto ? Icons.two_wheeler : Icons.directions_car, size: 22),
            Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(price == null ? t.description : pkr(price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _tile(Color color, String text, VoidCallback onTap, {bool placeholder = false}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(Icons.circle, size: 12, color: color),
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
