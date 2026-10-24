import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../call_screen.dart';
import '../chat_screen.dart';
import '../../widgets/review_input.dart';

/// Passenger ne driver ki offer accept kar li: pickup se drop tak.
class DriverRideView extends StatefulWidget {
  final RideRequest ride;
  const DriverRideView({super.key, required this.ride});

  @override
  State<DriverRideView> createState() => _DriverRideViewState();
}

class _DriverRideViewState extends State<DriverRideView> {
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
      RideStatus.completed =>
        ride.payment == PaymentMethod.wallet ? '${pkr(fare)} paid to your wallet' : 'Collect ${pkr(fare)} cash',
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
                ServiceInfo(ride: ride),
                if (ride.scheduledAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Pickup: ${ride.scheduledAt!.day}/${ride.scheduledAt!.month} at ${hhmm(ride.scheduledAt!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
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
          ReviewInput(
            title: 'Rate your passenger',
            tags: passengerReviewTags,
            onSubmit: (stars, review) => store.closeDriverRide(passengerStars: stars, review: review),
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              store.raiseSos(ride);
              showSnack(context, 'SOS sent. Go Ride safety team is alerted.');
            },
            icon: const Icon(Icons.sos),
            label: const Text('SOS'),
          ),
          const SizedBox(height: 8),
          ContactButtons(
            ride: ride,
            openChat: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(ride: ride))),
          ),
          Row(children: [
            if (ride.status != RideStatus.inProgress) ...[
              Expanded(
                child: TextButton(
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
