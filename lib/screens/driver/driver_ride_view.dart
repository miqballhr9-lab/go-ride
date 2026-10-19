import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Passenger ne driver ki offer accept kar li: pickup se drop tak.
class DriverRideView extends StatelessWidget {
  final RideRequest ride;
  const DriverRideView({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final fare = ride.finalFare;

    final (title, buttonText, action) = switch (ride.status) {
      RideStatus.driverComing => ('Passenger ko lene jayen', 'Main pohanch gaya', store.driverArrived),
      RideStatus.driverArrived => ('Passenger ka intezar', 'Ride shuru karein', store.driverStartRide),
      RideStatus.inProgress => ('Manzil ki taraf', 'Ride mukammal', store.driverCompleteRide),
      RideStatus.completed => ('${pkr(fare)} cash wasool karein', 'Theek hai', store.closeDriverRide),
      _ => ('', 'Theek hai', store.closeDriverRide),
    };

    return Scaffold(
      body: Column(children: [
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
                const SizedBox(height: 12),
                Row(children: [
                  Avatar(ride.passengerName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${ride.passengerName}  ★ ${ride.passengerRating.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  Text(pkr(fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                ]),
                const SizedBox(height: 12),
                RouteLines(from: ride.from, to: ride.to),
                if (ride.comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('"${ride.comment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: action, child: Text(buttonText)),
                if (ride.status == RideStatus.driverComing || ride.status == RideStatus.driverArrived) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: store.driverCancelRide,
                    child: const Text('Ride cancel', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
