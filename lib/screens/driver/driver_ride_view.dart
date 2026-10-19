import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../chat_screen.dart';

/// Passenger ne driver ki offer accept kar li: pickup se drop tak.
class DriverRideView extends StatefulWidget {
  final RideRequest ride;
  const DriverRideView({super.key, required this.ride});

  @override
  State<DriverRideView> createState() => _DriverRideViewState();
}

class _DriverRideViewState extends State<DriverRideView> {
  int stars = 5;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ride = widget.ride;
    final fare = ride.finalFare;
    final p = store.userById(ride.passengerId);

    final title = switch (ride.status) {
      RideStatus.driverComing => 'Go to pickup',
      RideStatus.driverArrived => 'Waiting for passenger',
      RideStatus.inProgress => 'Heading to destination',
      RideStatus.completed => 'Collect ${pkr(fare)} cash',
      RideStatus.cancelled => 'Ride cancelled',
      RideStatus.searching => '',
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
                if (ride.status == RideStatus.cancelled)
                  Text(ride.cancelReason ?? '', style: const TextStyle(color: AppColors.muted)),
                if (ride.status == RideStatus.completed)
                  Text('Go Ride commission: ${pkr(ride.commission)} · You keep ${pkr(fare - ride.commission)}',
                      style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Avatar(p.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${p.name}  ★ ${p.passengerRating.toStringAsFixed(1)}',
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
                ..._actions(store, ride),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _actions(AppStore store, RideRequest ride) {
    switch (ride.status) {
      case RideStatus.completed:
        return [
          const Text('Rate your passenger', textAlign: TextAlign.center),
          StarPicker(value: stars, onChanged: (v) => setState(() => stars = v)),
          FilledButton(
            onPressed: () => store.closeDriverRide(passengerStars: stars),
            child: const Text('Done'),
          ),
        ];
      case RideStatus.cancelled:
        return [FilledButton(onPressed: () => store.closeDriverRide(), child: const Text('OK'))];
      default:
        final (buttonText, action) = switch (ride.status) {
          RideStatus.driverComing => ('I have arrived', store.driverArrived),
          RideStatus.driverArrived => ('Start ride', store.driverStartRide),
          _ => ('Complete ride', store.driverCompleteRide),
        };
        return [
          FilledButton(onPressed: action, child: Text(buttonText)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(ride.chat.isEmpty ? 'Chat' : 'Chat (${ride.chat.length})'),
              ),
            ),
            if (ride.status != RideStatus.inProgress) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final reason =
                        await pickReason(context, 'Why are you cancelling?', AppStore.driverCancelReasons);
                    if (reason != null) store.driverCancelRide(reason);
                  },
                  child: const Text('Cancel ride'),
                ),
              ),
            ],
          ]),
        ];
    }
  }
}
