import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

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
    final offer = ride.acceptedOffer!;
    final d = offer.driver;

    final (title, subtitle) = switch (ride.status) {
      RideStatus.driverComing => ('Driver aa raha hai', '${offer.etaMinutes} min mein pohanchega'),
      RideStatus.driverArrived => ('Driver pohanch gaya', 'Bahar aa jayen, ${d.vehicle.color} ${d.vehicle.model}'),
      RideStatus.inProgress => ('Safar jaari hai', 'Manzil: ${ride.to.name}'),
      RideStatus.completed => ('Aap pohanch gaye', 'Driver ko ${pkr(offer.fare)} cash ada karein'),
      _ => ('', ''),
    };

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: RideMap(from: ride.from, to: ride.to)),
          Container(
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
                        Text('${d.name}  ★ ${d.rating}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('${d.vehicle.color} ${d.vehicle.model}'),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.dark, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.vehicle.plate, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  RouteLines(from: ride.from, to: ride.to),
                  const SizedBox(height: 8),
                  Text('Kiraya: ${pkr(offer.fare)} (cash)',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  if (ride.status == RideStatus.completed) ...[
                    const Text('Driver ko rating dein', textAlign: TextAlign.center),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          IconButton(
                            iconSize: 36,
                            onPressed: () => setState(() => stars = i),
                            icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: Colors.amber),
                          ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () => store.ratePassengerRide(stars),
                      child: const Text('Mukammal'),
                    ),
                  ] else
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _snack(context, 'Call: demo mein dastyab nahi'),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (ride.status != RideStatus.inProgress)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                            onPressed: store.cancelPassengerRide,
                            child: const Text('Ride cancel'),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                            onPressed: () => _snack(context, 'SOS: emergency contact ko alert (demo)'),
                            icon: const Icon(Icons.sos),
                            label: const Text('SOS'),
                          ),
                        ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
