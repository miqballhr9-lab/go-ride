import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../call_screen.dart';
import '../chat_screen.dart';
import '../../widgets/review_input.dart';

/// Offer accept hone ke baad passenger ka ride screen.
class PassengerRideView extends StatefulWidget {
  final RideRequest ride;
  const PassengerRideView({super.key, required this.ride});

  @override
  State<PassengerRideView> createState() => _PassengerRideViewState();
}

class _PassengerRideViewState extends State<PassengerRideView> {
  // Driver ki gari map pe chalti dikhane ke liye har second rebuild.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  final DateTime _start = DateTime.now();

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  /// Demo GPS: driver pickup ki taraf, phir manzil ki taraf barhta hai.
  LatLng? _carPosition(RideRequest ride) {
    final secs = DateTime.now().difference(_start).inMilliseconds / 1000;
    LatLng lerp(LatLng a, LatLng b, double t) =>
        LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
    switch (ride.status) {
      case RideStatus.driverComing:
        final startPoint = LatLng(ride.from.point.latitude + 0.02, ride.from.point.longitude - 0.02);
        return lerp(startPoint, ride.from.point, (secs / 6).clamp(0, 0.95));
      case RideStatus.driverArrived:
        return ride.from.point;
      case RideStatus.inProgress:
        return lerp(ride.from.point, ride.to.point, ((secs % 12) / 12).clamp(0, 1));
      default:
        return null;
    }
  }
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ride = widget.ride;
    final offer = ride.acceptedOffer;
    if (offer == null) {
      // Driver milne se pehle hi support ne request cancel kar di.
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.cancel_outlined, size: 64, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Ride request cancelled',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(ride.cancelReason ?? '', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => store.closePassengerRide(), child: const Text('OK')),
            ]),
          ),
        ),
      );
    }
    final d = store.userById(offer.driverId);
    final v = d.driver!.vehicle;

    final shop = ride.service == ServiceType.groceries;
    final (title, subtitle) = switch (ride.status) {
      // Groceries: driver store jata hai, saman khareedta hai, phir lata hai.
      RideStatus.driverComing when shop => ('Shopper is going to the store', ride.from.name),
      RideStatus.driverArrived when shop => ('Shopper is buying your items', '${ride.grocery!.items.length} items at ${ride.from.name}'),
      RideStatus.driverComing => ride.scheduledAt != null
          ? ('Driver confirmed', 'Pickup on ${ride.scheduledAt!.day}/${ride.scheduledAt!.month} at ${hhmm(ride.scheduledAt!)}')
          : ('Driver is on the way', 'Arriving in ${offer.etaMinutes} min'),
      RideStatus.driverArrived => ('Your driver has arrived', 'Look for a ${v.color} ${v.model}'),
      RideStatus.inProgress => (
          ride.service == ServiceType.ride ? 'On the way' : 'Delivery in progress',
          'Destination: ${ride.to.name}'
        ),
      RideStatus.completed => (
          ride.service == ServiceType.ride ? 'You have arrived' : 'Delivered',
          ride.payment == PaymentMethod.wallet
              ? '${pkr(ride.passengerPays)} paid from your wallet${shop ? '. Pay the item cost to the driver' : ''}'
              : shop
                  ? 'Pay the item cost (about ${pkr(ride.grocery!.budget)}) plus ${pkr(ride.passengerPays)} fare'
                  : 'Please pay ${pkr(ride.passengerPays)} cash to the driver'
        ),
      RideStatus.cancelled => ('Ride cancelled', ride.cancelReason ?? ''),
      RideStatus.searching => ('', ''),
    };

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RideMap(from: ride.from, to: ride.to, cars: [?_carPosition(ride)]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Avatar(d.name, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.name}  ★ ${d.driverRating.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('${v.color} ${v.model}'),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.dark, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(v.plate, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  RouteLines(from: ride.from, to: ride.to),
                  const SizedBox(height: 8),
                  ServiceInfo(ride: ride),
                  const SizedBox(height: 8),
                  Text(
                      ride.discount > 0
                          ? 'Fare: ${pkr(offer.fare)} − promo ${pkr(ride.discount)} = ${pkr(ride.passengerPays)} (${ride.payment.label.toLowerCase()})'
                          : 'Fare: ${pkr(offer.fare)} (${ride.payment.label.toLowerCase()})',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  ..._actions(store, ride),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(AppStore store, RideRequest ride) {
    switch (ride.status) {
      case RideStatus.completed:
        return [
          ReviewInput(
            title: 'Rate your driver',
            tags: driverReviewTags,
            onSubmit: (stars, review) => store.closePassengerRide(stars: stars, review: review),
          ),
        ];
      case RideStatus.cancelled:
        return [
          FilledButton(onPressed: () => store.closePassengerRide(), child: const Text('Find another ride')),
        ];
      default:
        final started = ride.status == RideStatus.inProgress;
        return [
          ContactButtons(
            ride: ride,
            openChat: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showSnack(context, 'Trip details copied to share (demo)'),
            icon: const Icon(Icons.share_location),
            label: const Text('Share trip'),
          ),
          const SizedBox(height: 10),
          if (!started)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final reason =
                    await pickReason(context, 'Why are you cancelling?', AppStore.passengerCancelReasons);
                if (reason != null) store.cancelPassengerRide(reason);
              },
              child: const Text('Cancel ride'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () {
                store.raiseSos(ride);
                showSnack(context, 'SOS sent. MIK DRIVE safety team is alerted and can see your trip. Call 15 if needed.');
              },
              icon: const Icon(Icons.sos),
              label: const Text('SOS'),
            ),
        ];
    }
  }
}
