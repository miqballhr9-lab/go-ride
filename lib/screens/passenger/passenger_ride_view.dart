import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../chat_screen.dart';

/// Offer accept hone ke baad passenger ka ride screen.
class PassengerRideView extends StatefulWidget {
  final RideRequest ride;
  const PassengerRideView({super.key, required this.ride});

  @override
  State<PassengerRideView> createState() => _PassengerRideViewState();
}

class _PassengerRideViewState extends State<PassengerRideView> {
  int stars = 5;

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

    final (title, subtitle) = switch (ride.status) {
      RideStatus.driverComing => ('Driver is on the way', 'Arriving in ${offer.etaMinutes} min'),
      RideStatus.driverArrived => ('Your driver has arrived', 'Look for a ${v.color} ${v.model}'),
      RideStatus.inProgress => ('On the way', 'Destination: ${ride.to.name}'),
      RideStatus.completed => ('You have arrived', 'Please pay ${pkr(offer.fare)} cash to the driver'),
      RideStatus.cancelled => ('Ride cancelled', ride.cancelReason ?? ''),
      RideStatus.searching => ('', ''),
    };

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: RideMap(from: ride.from, to: ride.to)),
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
                  Text('Fare: ${pkr(offer.fare)} (cash)', style: const TextStyle(fontWeight: FontWeight.w800)),
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
          const Text('Rate your driver', textAlign: TextAlign.center),
          StarPicker(value: stars, onChanged: (v) => setState(() => stars = v)),
          FilledButton(onPressed: () => store.closePassengerRide(stars: stars), child: const Text('Done')),
        ];
      case RideStatus.cancelled:
        return [
          FilledButton(onPressed: () => store.closePassengerRide(), child: const Text('Find another ride')),
        ];
      default:
        final started = ride.status == RideStatus.inProgress;
        return [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(ride.chat.isEmpty ? 'Chat' : 'Chat (${ride.chat.length})'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showSnack(context, 'Trip details copied to share (demo)'),
                icon: const Icon(Icons.share_location),
                label: const Text('Share trip'),
              ),
            ),
          ]),
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
              onPressed: () => showSnack(context, 'SOS: calling 15 and alerting Go Ride support (demo)'),
              icon: const Icon(Icons.sos),
              label: const Text('SOS'),
            ),
        ];
    }
  }
}
