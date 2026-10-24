import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
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
            onPressed: () async {
              final reason = await pickReason(context, 'Why are you cancelling?', AppStore.passengerCancelReasons);
              if (reason != null) store.cancelPassengerRide(reason);
            },
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
              ServiceInfo(ride: ride),
              if (ride.scheduledAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      '${ride.service == ServiceType.intercity ? 'Departure' : 'Pickup'}: ${ride.scheduledAt!.day}/${ride.scheduledAt!.month} at ${hhmm(ride.scheduledAt!)}'
                      '${ride.service == ServiceType.intercity ? ' · ${ride.seats} passenger${ride.seats > 1 ? 's' : ''}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              if (ride.discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Promo ${ride.promoCode}: you save ${pkr(ride.discount)}',
                      style: TextStyle(color: Colors.green.shade700)),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text('${ride.vehicleType.label} · ${pkr(ride.fare)} · ${ride.payment.label}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
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
                Text('Your request has been sent to nearby drivers...',
                    style: TextStyle(color: AppColors.muted)),
                SizedBox(height: 4),
                Text('Raise your fare to get offers faster',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
    final d = store.userById(offer.driverId);
    final v = d.driver!.vehicle;
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
                Text('★ ${d.driverRating.toStringAsFixed(2)}  ·  ${d.driverRatingCount} ratings',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text(v.toString(), style: const TextStyle(fontSize: 13)),
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
                child: const Text('Decline'),
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
