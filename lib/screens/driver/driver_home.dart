import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../store.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../wallet_screen.dart';
import 'driver_registration.dart';
import 'driver_ride_view.dart';

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.currentUser!;
    final profile = user.driver;
    if (profile == null) {
      return const DriverRegistration();
    }
    if (profile.status != DriverStatus.approved) return _DriverStatusScreen(profile: profile);
    if (store.driverRide != null) return DriverRideView(ride: store.driverRide!);

    final net = store.todayGross - store.todayCommission;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leadingWidth: 96,
        leading: BackMenuLeading(onBack: StoreScope.of(context).goBack),
        title: const Text('Driver mode', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Text(store.driverOnline ? 'Online' : 'Offline',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: store.driverOnline ? Colors.green : AppColors.muted)),
          Switch(
            value: store.driverOnline,
            activeTrackColor: AppColors.brand,
            onChanged: (v) {
              if (v && !store.canGoOnline) {
                showSnack(context, 'Your wallet balance is below zero. Top up to go online.');
                return;
              }
              store.setDriverOnline(v);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              _stat('Today (net)', pkr(net)),
              _stat('Commission', pkr(store.todayCommission)),
              _stat('Rides', '${store.todayTrips}'),
              _stat('Wallet', pkr(user.walletBalance), warn: user.walletBalance < 0),
            ]),
          ),
        ),
        if (!store.canGoOnline)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Expanded(
                child: Text('Balance below zero. Top up to receive requests.',
                    style: TextStyle(color: AppColors.danger)),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                child: const Text('Top up'),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${profile.vehicle.type.label} requests',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Spacer(),
            Text(profile.vehicle.plate, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: !store.driverOnline
              ? const _Empty(icon: Icons.power_settings_new, text: 'Go online to see ride requests')
              : store.openRequests.isEmpty
                  ? const _Empty(icon: Icons.hourglass_empty, text: 'Waiting for requests...')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: store.openRequests.length,
                      itemBuilder: (_, i) => _RequestCard(req: store.openRequests[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, {bool warn = false}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: warn ? const Color(0xFFFF8A8A) : AppColors.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ]),
      );
}

class _DriverStatusScreen extends StatelessWidget {
  final DriverProfile profile;
  const _DriverStatusScreen({required this.profile});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final (icon, color, title, text) = switch (profile.status) {
      DriverStatus.pending => (
          Icons.hourglass_top,
          Colors.orange.shade800,
          'Application under review',
          'Our team is checking your documents. This usually takes up to 24 hours. '
              'You will be able to go online once you are approved.'
        ),
      DriverStatus.rejected => (
          Icons.cancel_outlined,
          AppColors.danger,
          'Application not approved',
          'Reason: ${profile.rejectionReason ?? 'Not specified'}. You can fix this and apply again.'
        ),
      _ => (
          Icons.block,
          AppColors.danger,
          'Driver account blocked',
          'Your driver account has been blocked. Please contact support for details.'
        ),
    };
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leadingWidth: 96,
        leading: BackMenuLeading(onBack: StoreScope.of(context).goBack),
        title: const Text('Driver mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(icon, size: 72, color: color),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          if (profile.status == DriverStatus.rejected)
            FilledButton(
              onPressed: store.reapplyDriver,
              child: const Text('Apply again'),
            ),
          if (profile.status == DriverStatus.pending)
            const Text('Demo: approve this driver from the Control office login.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => store.switchMode(AppMode.passenger),
            child: const Text('Back to passenger mode'),
          ),
        ]),
      ),
    );
  }
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
    final p = store.userById(req.passengerId);
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
              Avatar(p.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${p.name}  ★ ${p.passengerRating.toStringAsFixed(1)}',
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(pkr(req.fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              StatusChip(req.service.label, AppColors.dark),
              if (req.payment == PaymentMethod.wallet) StatusChip('Wallet', Colors.green.shade700),
            ]),
            const SizedBox(height: 8),
            RouteLines(from: req.from, to: req.to),
            ServiceInfo(ride: req, showReceiverPhone: false),
            const SizedBox(height: 6),
            Text('${req.distanceKm.toStringAsFixed(1)} km · ${timeAgo(req.createdAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (req.comment.isNotEmpty)
              Text('"${req.comment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            if (offered) ...[
              const SizedBox(height: 8),
              const Row(children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Offer sent, waiting for the passenger...'),
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
  final AppStore store = StoreScope.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      void send(int fare) {
        store.sendDriverOffer(req, fare);
        Navigator.pop(ctx);
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RouteLines(from: req.from, to: req.to),
            ServiceInfo(ride: req, showReceiverPhone: false),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => send(req.fare), child: Text('Accept for ${pkr(req.fare)}')),
            const SizedBox(height: 16),
            const Text('Or offer your fare:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              for (final (i, bump) in (req.service == ServiceType.freight ? [100, 250, 500] : [20, 50, 100]).indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => send(req.fare + bump),
                    child: Text(pkr(req.fare + bump)),
                  ),
                ),
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
