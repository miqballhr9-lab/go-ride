import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Buses: sheheron ke darmiyan bus ki seat booking (fixed kiraya).
class BusesScreen extends StatefulWidget {
  const BusesScreen({super.key});

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  late String from = StoreScope.of(context).currentCity.name;
  late String to = AppStore.cities.firstWhere((c) => c != from);
  DateTime day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final trips = store.searchBuses(from, to, day);
    final today = DateTime.now();
    final days = [for (var i = 0; i < 3; i++) DateTime(today.year, today.month, today.day + i)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buses'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text('My tickets (${store.myBusBookings.where((b) => !b.cancelled).length})'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _cityPicker('From', from, (c) => setState(() => from = c))),
            IconButton(
              tooltip: 'Swap',
              onPressed: () => setState(() {
                final t = from;
                from = to;
                to = t;
              }),
              icon: const Icon(Icons.swap_horiz),
            ),
            Expanded(child: _cityPicker('To', to, (c) => setState(() => to = c))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final (i, d) in days.indexed)
              ChoiceChip(
                label: Text(i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : '${d.day}/${d.month}')),
                selected: d.day == day.day && d.month == day.month,
                onSelected: (_) => setState(() => day = d),
              ),
          ]),
          const SizedBox(height: 12),
          if (from == to)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Choose two different cities', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            )
          else if (trips.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No buses left for this day. Try another date.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final t in trips) _TripCard(trip: t),
        ],
      ),
    );
  }

  Widget _cityPicker(String label, String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [for (final c in AppStore.cities) DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (v) => onChanged(v!),
      );
}

class _TripCard extends StatelessWidget {
  final BusTrip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final h = trip.duration.inHours, m = trip.duration.inMinutes % 60;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFC9D2D6))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _book(context, trip),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_bus, color: AppColors.dark),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.operator, style: const TextStyle(fontWeight: FontWeight.w700))),
              StatusChip(trip.busType, trip.busType == 'Business' ? AppColors.dark : AppColors.brand),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text(hhmm(trip.departs), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Expanded(
                child: Column(children: [
                  Text('${h}h${m > 0 ? ' ${m}m' : ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const Divider(indent: 12, endIndent: 12),
                ]),
              ),
              Text(hhmm(trip.arrives), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            Row(children: [
              Text(trip.fromCity, style: const TextStyle(color: AppColors.muted)),
              const Spacer(),
              Text(trip.toCity, style: const TextStyle(color: AppColors.muted)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('${trip.seatsLeft} seats left',
                  style: TextStyle(color: trip.seatsLeft < 5 ? AppColors.danger : AppColors.muted)),
              const Spacer(),
              Text('${pkr(trip.pricePerSeat)} / seat', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ]),
        ),
      ),
    );
  }
}

Future<void> _book(BuildContext context, BusTrip trip) async {
  final store = StoreScope.of(context);
  var seats = 1;
  var payment = PaymentMethod.cash;
  String? error;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${trip.operator} · ${trip.fromCity} → ${trip.toCity}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('${trip.departs.day}/${trip.departs.month} at ${hhmm(trip.departs)} · ${trip.busType}',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Seats', style: TextStyle(fontSize: 16))),
              IconButton(
                  onPressed: seats > 1 ? () => setS(() => seats--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(
                  onPressed: seats < 6 && seats < trip.seatsLeft ? () => setS(() => seats++) : null,
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              for (final m in PaymentMethod.values) ...[
                Expanded(
                  child: ChoiceChip(
                    label: Text(m == PaymentMethod.cash
                        ? 'Pay at terminal'
                        : 'Wallet · ${pkr(store.currentUser!.walletBalance)}'),
                    selected: payment == m,
                    onSelected: (_) => setS(() => payment = m),
                  ),
                ),
                if (m == PaymentMethod.cash) const SizedBox(width: 8),
              ],
            ]),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final err = store.bookBus(trip, seats, payment);
                if (err != null) {
                  setS(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                showSnack(context, 'Ticket booked. Find it in My tickets.');
              },
              child: Text('Book $seats seat${seats > 1 ? 's' : ''} · ${pkr(trip.pricePerSeat * seats)}'),
            ),
          ]),
        ),
      ),
    ),
  );
}

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.myBusBookings;
    return Scaffold(
      appBar: AppBar(title: const Text('My bus tickets')),
      body: list.isEmpty
          ? const Center(child: Text('No tickets yet', style: TextStyle(color: AppColors.muted)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final b in list)
                  Builder(builder: (context) {
                    final t = store.busTripById(b.tripId);
                    return Card(
                      elevation: 0,
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text('${t.fromCity} → ${t.toCity}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            StatusChip(b.cancelled ? 'Cancelled' : 'Booked', b.cancelled ? AppColors.danger : AppColors.brand),
                          ]),
                          const SizedBox(height: 4),
                          Text('${t.operator} · ${t.busType}'),
                          Text('${t.departs.day}/${t.departs.month} at ${hhmm(t.departs)} · ${b.seats} seat${b.seats > 1 ? 's' : ''}'),
                          Text('Ticket ${b.id} · ${pkr(b.total)} · ${b.payment == PaymentMethod.wallet ? 'paid from wallet' : 'pay at terminal'}',
                              style: const TextStyle(color: AppColors.muted)),
                          if (!b.cancelled)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  final err = store.cancelBusBooking(b);
                                  showSnack(context, err ?? 'Ticket cancelled');
                                },
                                child: const Text('Cancel ticket', style: TextStyle(color: AppColors.danger)),
                              ),
                            ),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
