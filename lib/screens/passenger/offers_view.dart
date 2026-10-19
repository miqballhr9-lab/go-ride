import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Passenger ki request ke baad drivers ki offers yahan aati hain.
class OffersView extends StatelessWidget {
  final RideRequest ride;
  const OffersView({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver offers'),
        actions: [
          TextButton(
            onPressed: store.cancelPassengerRide,
            child: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RouteLines(from: ride.from, to: ride.to),
              const SizedBox(height: 12),
              Row(children: [
                Text('Aap ka kiraya: ${pkr(ride.fare)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => store.raiseFare(ride.fare + 20),
                  child: const Text('+ Rs 20'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (ride.offers.isEmpty)
            const Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: AppColors.dark),
                SizedBox(height: 16),
                Text('Qareebi drivers ko request bhej di gayi hai...',
                    style: TextStyle(color: AppColors.muted)),
              ]),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ride.offers.length,
                itemBuilder: (_, i) => _OfferCard(offer: ride.offers[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Offer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = offer.driver;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Avatar(d.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('★ ${d.rating}  ·  ${d.trips} rides',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text(d.vehicle.toString(), style: const TextStyle(fontSize: 13)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pkr(offer.fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text('${offer.etaMinutes} min', style: const TextStyle(color: AppColors.muted)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => store.declineOffer(offer),
                child: const Text('Mana karein'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => store.acceptOffer(offer),
                child: const Text('Accept'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
