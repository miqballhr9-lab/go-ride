import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'driver_registration.dart';
import 'driver_ride_view.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.user!;
    if (!user.isDriverRegistered) return const DriverRegistration();
    if (store.driverRide != null) return DriverRideView(ride: store.driverRide!);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Driver mode', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Text(store.driverOnline ? 'Online' : 'Offline',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: store.driverOnline ? Colors.green : AppColors.muted)),
          Switch(
            value: store.driverOnline,
            activeTrackColor: AppColors.brand,
            onChanged: store.setDriverOnline,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            _stat('Aaj ki kamai', pkr(store.todayEarnings)),
            _stat('Rides', '${store.todayTrips}'),
            _stat('Gari', user.vehicle!.plate),
          ]),
        ),
        Expanded(
          child: !store.driverOnline
              ? const _Empty(
                  icon: Icons.power_settings_new,
                  text: 'Ride requests dekhne ke liye Online ho jayen')
              : store.openRequests.isEmpty
                  ? const _Empty(icon: Icons.hourglass_empty, text: 'Requests ka intezar...')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: store.openRequests.length,
                      itemBuilder: (_, i) => _RequestCard(req: store.openRequests[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

class _RequestCard extends StatelessWidget {
  final RideRequest req;
  const _RequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final offered = store.hasOffered(req);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: offered ? null : () => _openOfferSheet(context, req),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(req.passengerName, size: 36),
              const SizedBox(width: 10),
              Text('${req.passengerName}  ★ ${req.passengerRating.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(pkr(req.fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 10),
            RouteLines(from: req.from, to: req.to),
            const SizedBox(height: 6),
            Text('${req.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (req.comment.isNotEmpty)
              Text('"${req.comment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            if (offered) ...[
              const SizedBox(height: 8),
              const Row(children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Offer bhej di, passenger ke jawab ka intezar...'),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// inDrive jaisa: passenger ka kiraya accept karein ya apna kiraya offer karein.
void _openOfferSheet(BuildContext context, RideRequest req) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final store = StoreScope.of(context);
      void send(int fare) {
        store.sendDriverOffer(req, fare);
        Navigator.pop(ctx);
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RouteLines(from: req.from, to: req.to),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => send(req.fare),
              child: Text('${pkr(req.fare)} mein accept karein'),
            ),
            const SizedBox(height: 16),
            const Text('Ya apna kiraya offer karein:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              for (final bump in [20, 50, 100]) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => send(req.fare + bump),
                    child: Text(pkr(req.fare + bump)),
                  ),
                ),
                if (bump != 100) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.muted),
              onPressed: () {
                store.skipRequest(req);
                Navigator.pop(ctx);
              },
              child: const Text('Skip'),
            ),
          ]),
        ),
      );
    },
  );
}
