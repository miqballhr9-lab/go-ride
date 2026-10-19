import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_ops.dart';
import 'admin_shell.dart';

Color driverStatusColor(DriverStatus s) => switch (s) {
      DriverStatus.pending => Colors.orange.shade800,
      DriverStatus.approved => Colors.green.shade700,
      DriverStatus.rejected => AppColors.danger,
      DriverStatus.blocked => AppColors.danger,
    };

class AdminDrivers extends StatefulWidget {
  const AdminDrivers({super.key});

  @override
  State<AdminDrivers> createState() => _AdminDriversState();
}

class _AdminDriversState extends State<AdminDrivers> {
  DriverStatus filter = DriverStatus.pending;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.allDrivers;
    final q = query.toLowerCase();
    final list = all
        .where((u) => u.driver!.status == filter)
        .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.phone.contains(q) ||
            u.driver!.vehicle.plate.toLowerCase().contains(q))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in DriverStatus.values)
            ChoiceChip(
              label: Text('${s.label} (${all.where((u) => u.driver!.status == s).length})'),
              selected: filter == s,
              onSelected: (_) => setState(() => filter = s),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search), hintText: 'Search by name, phone or number plate'),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No drivers here', style: TextStyle(color: AppColors.muted))),
          ),
        if (list.isNotEmpty)
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final u in list)
                ListTile(
                  leading: Avatar(u.name, size: 40),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${u.driver!.vehicle.type.label} · ${u.driver!.vehicle} · ${u.phone}',
                      overflow: TextOverflow.ellipsis),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    StatusChip(u.driver!.status.label, driverStatusColor(u.driver!.status)),
                    const SizedBox(height: 2),
                    Text(u.driver!.status == DriverStatus.pending
                        ? timeAgo(u.driver!.submittedAt)
                        : '★ ${u.driverRating.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => DriverDetailScreen(user: u))),
                ),
            ]),
          ),
      ],
    );
  }
}

const _rejectReasons = [
  'Documents are unclear or missing',
  'CNIC details do not match',
  'Driving license expired',
  'Vehicle does not meet requirements',
  'Other',
];

class DriverDetailScreen extends StatelessWidget {
  final AppUser user;
  const DriverDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = user.driver!;
    final rides = store.rides.where((r) => r.driverId == user.id).toList();
    final completed = rides.where((r) => r.status == RideStatus.completed);
    final earned = completed.fold(0, (s, r) => s + r.finalFare);
    final commission = completed.fold(0, (s, r) => s + r.commission);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(user.name), backgroundColor: AppColors.surface),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AdminCard(
            child: Row(children: [
              Avatar(user.name, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('${user.phone} · ${user.email.isEmpty ? 'no email' : user.email}'),
                  Text('${user.city} · joined ${timeAgo(user.createdAt)}',
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  StatusChip(d.status.label, driverStatusColor(d.status)),
                  if (d.rejectionReason != null)
                    Text('Reason: ${d.rejectionReason}', style: const TextStyle(color: AppColors.danger)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AdminCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Application', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _kv('CNIC', d.cnic),
              _kv('License no.', d.licenseNo),
              _kv('Category', d.vehicle.type.label),
              _kv('Vehicle', '${d.vehicle.color} ${d.vehicle.model} (${d.vehicle.year})'),
              _kv('Number plate', d.vehicle.plate),
              _kv('Submitted', timeAgo(d.submittedAt)),
              const SizedBox(height: 12),
              const Text('Documents', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final doc in driverDocuments)
                  Chip(
                    avatar: Icon(d.documents.contains(doc) ? Icons.check_circle : Icons.error_outline,
                        size: 18, color: d.documents.contains(doc) ? Colors.green : AppColors.danger),
                    label: Text(doc),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (d.status == DriverStatus.approved || d.status == DriverStatus.blocked)
            AdminCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Performance', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _kv('Rating', '★ ${user.driverRating.toStringAsFixed(2)} (${user.driverRatingCount})'),
                _kv('Rides', '${completed.length} completed · ${rides.where((r) => r.status == RideStatus.cancelled).length} cancelled'),
                _kv('Fares', pkr(earned)),
                _kv('Commission', pkr(commission)),
                _kv('Online now', d.online ? 'Yes' : 'No'),
              ]),
            ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (d.status == DriverStatus.pending || d.status == DriverStatus.rejected)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () {
                  store.approveDriver(user);
                  showSnack(context, '${user.name} approved');
                },
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
            if (d.status == DriverStatus.pending)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48), foregroundColor: AppColors.danger),
                onPressed: () async {
                  final reason = await pickReason(context, 'Reject application', _rejectReasons);
                  if (reason != null) store.rejectDriver(user, reason);
                },
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            if (d.status == DriverStatus.approved)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48), foregroundColor: AppColors.danger),
                onPressed: () => store.setDriverBlocked(user, true),
                icon: const Icon(Icons.block),
                label: const Text('Block driver'),
              ),
            if (d.status == DriverStatus.blocked)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () => store.setDriverBlocked(user, false),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unblock driver'),
              ),
          ]),
          const SizedBox(height: 20),
          if (rides.isNotEmpty) ...[
            const Text('Rides', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            RideTable(rides: rides.take(20).toList()),
          ],
        ],
      ),
    );
  }
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted))),
        Expanded(child: Text(v)),
      ]),
    );

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = query.toLowerCase();
    final list = store.allPassengers
        .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.phone.contains(q))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or phone'),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final u in list)
              ListTile(
                leading: Avatar(u.name, size: 40),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${u.phone} · ${u.city} · ★ ${u.passengerRating.toStringAsFixed(2)}'),
                trailing: Wrap(spacing: 6, children: [
                  if (u.driver != null) const StatusChip('Driver', AppColors.dark),
                  if (u.blocked) const StatusChip('Blocked', AppColors.danger),
                ]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(user: u))),
              ),
          ]),
        ),
      ],
    );
  }
}

class UserDetailScreen extends StatelessWidget {
  final AppUser user;
  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rides = store.rides.where((r) => r.passengerId == user.id).toList();
    final tickets = store.tickets.where((t) => t.userId == user.id).toList();
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(user.name), backgroundColor: AppColors.surface),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AdminCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv('Phone', user.phone),
              _kv('Email', user.email.isEmpty ? '-' : user.email),
              _kv('City', user.city),
              _kv('Joined', timeAgo(user.createdAt)),
              _kv('Rating', '★ ${user.passengerRating.toStringAsFixed(2)}'),
              _kv('Rides', '${rides.length}'),
              _kv('Support tickets', '${tickets.length}'),
              _kv('Account', user.blocked ? 'Blocked' : 'Active'),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (user.blocked)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () => store.setUserBlocked(user, false),
                icon: const Icon(Icons.lock_open),
                label: const Text('Unblock account'),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48), foregroundColor: AppColors.danger),
                onPressed: () => store.setUserBlocked(user, true),
                icon: const Icon(Icons.block),
                label: const Text('Block account'),
              ),
            if (user.driver != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => DriverDetailScreen(user: user))),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Driver profile'),
              ),
          ]),
          const SizedBox(height: 20),
          if (rides.isNotEmpty) ...[
            const Text('Rides as passenger', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            RideTable(rides: rides.take(20).toList()),
          ],
        ],
      ),
    );
  }
}
