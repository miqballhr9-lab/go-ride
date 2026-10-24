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
  Place? from;
  Place? to;
  String? _city;
  DateTime? scheduledAt; // null = abhi
  int seats = 1;
  final promoCtrl = TextEditingController();
  int discount = 0;
  String? promoMsg;
  bool bannerDismissed = false;
  VehicleType type = VehicleType.mini;
  PaymentMethod payment = PaymentMethod.cash;
  ParcelDetails? parcel;
  FreightDetails? freight;
  final fareCtrl = TextEditingController();
  final commentCtrl = TextEditingController();
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sheher badla (profile se) to jaghein naye sheher ki.
    final city = StoreScope.of(context).currentCity;
    if (_city != city.name) {
      _city = city.name;
      from = city.places.first;
      to = null;
    }
  }

  @override
  void dispose() {
    fareCtrl.dispose();
    commentCtrl.dispose();
    promoCtrl.dispose();
    super.dispose();
  }

  int? _suggested(AppStore store, [VehicleType? t]) => (from != null && to != null)
      ? store.suggestedFare(t ?? type, from!, to!,
          parcel: service == ServiceType.courier ? parcel : null,
          freight: service == ServiceType.freight ? freight : null,
          service: service)
      : null;

  void _applyPromo() {
    final store = StoreScope.of(context);
    final fare = int.tryParse(fareCtrl.text.trim()) ?? _suggested(store) ?? 0;
    if (promoCtrl.text.trim().isEmpty) {
      setState(() {
        discount = 0;
        promoMsg = null;
      });
      return;
    }
    final (d, err) = store.checkPromo(promoCtrl.text, fare);
    setState(() {
      discount = d;
      promoMsg = err ?? 'You save ${pkr(d)} on this trip';
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      scheduledAt = at.isBefore(now.add(const Duration(minutes: 15))) ? null : at;
      if (scheduledAt == null) error = 'Choose a time at least 15 minutes from now';
    });
  }

  void _refreshFare() {
    final s = _suggested(StoreScope.of(context));
    if (s != null) fareCtrl.text = '$s';
  }

  void _setService(ServiceType s) {
    setState(() {
      service = s;
      error = null;
      if (!s.vehicles.contains(type)) type = s == ServiceType.freight ? s.vehicles.first : s.vehicles[1];
      // Intercity mein manzil doosra sheher hoti hai.
      if (s == ServiceType.intercity || (to != null && !StoreScope.of(context).currentCity.places.contains(to))) {
        to = null;
      }
      if (s == ServiceType.freight) scheduledAt = null;
    });
    _refreshFare();
  }

  void _pickTo() async {
    final store = StoreScope.of(context);
    final p = await pickPlace(
      context,
      switch (service) {
        ServiceType.ride => 'Where to?',
        ServiceType.intercity => 'Which city?',
        _ => 'Delivery address',
      },
      exclude: from,
      places: service == ServiceType.intercity ? store.intercityDestinations(store.currentCity.name) : null,
    );
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
    if (service == ServiceType.intercity && scheduledAt == null) {
      setState(() => error = 'Choose a departure date and time');
      return;
    }
    if (service == ServiceType.freight && freight!.weightKg > type.maxKg) {
      setState(() => error = '${type.label} carries up to ${type.maxKg} kg. Choose a bigger vehicle.');
      return;
    }
    final p = service == ServiceType.courier ? parcel : null;
    final f = service == ServiceType.freight ? freight : null;
    final minFare = store.lowestAllowedFare(type, from!, to!, parcel: p, freight: f, service: service);
    if (fare == null || fare < minFare) {
      setState(() => error = 'Minimum fare for this trip is ${pkr(minFare)}');
      return;
    }
    final err = store.createRequest(type, from!, to!, fare, commentCtrl.text.trim(),
        service: service,
        payment: payment,
        parcel: p,
        freight: f,
        scheduledAt: scheduledAt,
        seats: service == ServiceType.intercity ? seats : 1,
        promo: promoCtrl.text);
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
              center: store.currentCity.center,
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
                  child: Column(children: [
                    Row(children: [
                    FloatingActionButton.small(
                      heroTag: 'back',
                      tooltip: 'Back',
                      backgroundColor: Colors.white,
                      onPressed: store.goBack,
                      child: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 6),
                    FloatingActionButton.small(
                      heroTag: 'menu',
                      backgroundColor: Colors.white,
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      child: const Icon(Icons.menu),
                    ),
                    const Spacer(),
                    const NotificationBell(onMap: true),
                    ]),
                    const SizedBox(height: 8),
                    _serviceTabs(),
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
                    Icon(serviceIcon(s), size: 16),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(s.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
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
              if (store.bannerActive && !bannerDismissed) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.campaign_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(store.bannerText, style: const TextStyle(fontSize: 13))),
                    IconButton(
                      tooltip: 'Hide',
                      onPressed: () => setState(() => bannerDismissed = true),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
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
              _tile(
                  service == ServiceType.intercity ? Icons.location_city : Icons.circle,
                  AppColors.dark,
                  to?.name ??
                      switch (service) {
                        ServiceType.ride => 'Where to?',
                        ServiceType.intercity => 'Which city?',
                        _ => 'Delivery address',
                      },
                  _pickTo,
                  placeholder: to == null),
              if (service != ServiceType.freight) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _tile(
                      Icons.schedule,
                      AppColors.dark,
                      scheduledAt == null
                          ? (service == ServiceType.intercity ? 'Departure date and time' : 'Now')
                          : 'Scheduled: ${_when(scheduledAt!)}',
                      _pickTime,
                      placeholder: scheduledAt == null && service == ServiceType.intercity,
                    ),
                  ),
                  if (scheduledAt != null)
                    IconButton(
                      tooltip: 'Ride now',
                      onPressed: () => setState(() => scheduledAt = null),
                      icon: const Icon(Icons.close),
                    ),
                ]),
              ],
              if (service == ServiceType.intercity) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.event_seat_outlined, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Passengers', style: TextStyle(fontSize: 16))),
                  IconButton(
                    onPressed: seats > 1 ? () => setState(() => seats--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: seats < 4 ? () => setState(() => seats++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ]),
              ],
              if (service == ServiceType.courier || service == ServiceType.freight) ...[
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
                onChanged: (_) {
                  if (discount > 0) _applyPromo();
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: promoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_offer_outlined), hintText: 'Promo code', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _applyPromo,
                  child: const Text('Apply'),
                ),
              ]),
              if (promoMsg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(promoMsg!,
                      style: TextStyle(fontSize: 12, color: discount > 0 ? AppColors.dark : AppColors.danger, fontWeight: FontWeight.w600)),
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
                  ServiceType.intercity => 'Find an intercity driver',
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final day = t.day == now.day && t.month == now.month
        ? 'Today'
        : (t.difference(DateTime(now.year, now.month, now.day)).inDays == 1 ? 'Tomorrow' : '${t.day}/${t.month}');
    return '$day, ${hhmm(t)}';
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
