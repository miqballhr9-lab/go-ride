import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../wallet_screen.dart';
import 'offers_view.dart';
import 'passenger_ride_view.dart';
import 'service_details_forms.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  ServiceType service = ServiceType.ride;
  Place? from = AppStore.places.first;
  Place? to;
  VehicleType type = VehicleType.mini;
  PaymentMethod payment = PaymentMethod.cash;
  ParcelDetails? parcel;
  FreightDetails? freight;
  final fareCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    fareCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  int? _suggested(AppStore store, [VehicleType? t]) => (from != null && to != null)
      ? store.suggestedFare(t ?? type, from!, to!,
          parcel: service == ServiceType.courier ? parcel : null,
          freight: service == ServiceType.freight ? freight : null)
      : null;

  void _refreshFare() {
    final s = _suggested(StoreScope.of(context));
    if (s != null) fareCtrl.text = '$s';
  }

  void _setService(ServiceType s) {
    setState(() {
      service = s;
      error = null;
      if (!s.vehicles.contains(type)) type = s == ServiceType.freight ? s.vehicles.first : s.vehicles[1];
    });
    _refreshFare();
  }

  void _pickTo() async {
    final p = await pickPlace(context, service == ServiceType.ride ? 'Where to?' : 'Delivery address', exclude: from);
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

  void _editDetails() async {
    if (service == ServiceType.courier) {
      final p = await editParcel(context, parcel, type);
      if (p != null) setState(() => parcel = p);
    } else if (service == ServiceType.freight) {
      final f = await editFreight(context, freight, type);
      if (f != null) setState(() => freight = f);
    }
    _refreshFare();
  }

  void _find() {
    final store = StoreScope.of(context);
    final fare = int.tryParse(fareCtrl.text.trim());
    setState(() => error = null);
    if (from == null || to == null) {
      setState(() => error = 'Choose both pickup and destination');
      return;
    }
    if (service == ServiceType.courier && parcel == null) {
      setState(() => error = 'Add parcel details');
      return;
    }
    if (service == ServiceType.freight && freight == null) {
      setState(() => error = 'Add cargo details');
      return;
    }
    if (service == ServiceType.freight && freight!.weightKg > type.maxKg) {
      setState(() => error = '${type.label} carries up to ${type.maxKg} kg. Choose a bigger vehicle.');
      return;
    }
    final p = service == ServiceType.courier ? parcel : null;
    final f = service == ServiceType.freight ? freight : null;
    final minFare = store.lowestAllowedFare(type, from!, to!, parcel: p, freight: f);
    if (fare == null || fare < minFare) {
      setState(() => error = 'Minimum fare for this trip is ${pkr(minFare)}');
      return;
    }
    final err = store.createRequest(type, from!, to!, fare, commentCtrl.text.trim(),
        service: service, payment: payment, parcel: p, freight: f);
    if (err != null) setState(() => error = err);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ride = store.passengerRide;
    if (ride != null) {
      return ride.status == RideStatus.searching ? OffersView(ride: ride) : PassengerRideView(ride: ride);
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: RideMap(
              from: from,
              to: to,
              cars: [
                for (final d in store.onlineDrivers)
                  if (service.vehicles.contains(d.driver!.vehicle.type)) d.driver!.location!
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Builder(
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    FloatingActionButton.small(
                      heroTag: 'menu',
                      backgroundColor: Colors.white,
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      child: const Icon(Icons.menu),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _serviceTabs()),
                  ]),
                ),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _requestCard(store)),
        ],
      ),
    );
  }

  Widget _serviceTabs() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Row(children: [
          for (final s in ServiceType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => _setService(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: s == service ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(serviceIcon(s), size: 18),
                    const SizedBox(width: 4),
                    Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ),
        ]),
      );

  Widget _requestCard(AppStore store) {
    final suggested = _suggested(store);
    final wallet = store.currentUser!.walletBalance;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 16, color: Colors.black12)],
      ),
      child: SingleChildScrollView(
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
                  for (final t in service.vehicles) ...[
                    Expanded(child: _typeTile(store, t)),
                    if (t != service.vehicles.last) const SizedBox(width: 8),
                  ],
                ]),
              ),
              const SizedBox(height: 10),
              _tile(Icons.circle, AppColors.brand, from?.name ?? 'Pickup', _pickFrom),
              const SizedBox(height: 8),
              _tile(Icons.circle, AppColors.dark,
                  to?.name ?? (service == ServiceType.ride ? 'Where to?' : 'Delivery address'), _pickTo,
                  placeholder: to == null),
              if (service != ServiceType.ride) ...[
                const SizedBox(height: 8),
                _tile(
                  service == ServiceType.courier ? Icons.inventory_2_outlined : Icons.local_shipping_outlined,
                  AppColors.dark,
                  _detailsSummary(),
                  _editDetails,
                  placeholder: (service == ServiceType.courier ? parcel : freight) == null,
                ),
              ],
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
                  helperText: suggested == null ? null : 'Recommended fare: ${pkr(suggested)}',
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                for (final m in PaymentMethod.values) ...[
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(m == PaymentMethod.cash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                          size: 18),
                      label: Text(m == PaymentMethod.cash ? 'Cash' : 'Wallet · ${pkr(wallet)}'),
                      selected: payment == m,
                      onSelected: (_) => setState(() => payment = m),
                    ),
                  ),
                  if (m == PaymentMethod.cash) const SizedBox(width: 8),
                ],
              ]),
              if (payment == PaymentMethod.wallet)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                    child: const Text('Top up wallet'),
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
              FilledButton(
                onPressed: _find,
                child: Text(switch (service) {
                  ServiceType.ride => 'Find a driver',
                  ServiceType.courier => 'Find a courier',
                  ServiceType.freight => 'Find a vehicle',
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _detailsSummary() {
    if (service == ServiceType.courier) {
      final p = parcel;
      return p == null ? 'Add parcel details' : '${p.size.label} · ${p.description} → ${p.receiverName}';
    }
    final f = freight;
    return f == null ? 'Add cargo details' : '${f.cargo} · ${f.weightKg} kg · ${f.helpers} helpers';
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(vehicleIcon(t), size: 22),
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
            Icon(icon, size: icon == Icons.circle ? 12 : 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: placeholder ? AppColors.muted : AppColors.dark)),
            ),
          ]),
        ),
      ),
    );
  }
}
