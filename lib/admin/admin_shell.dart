import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_ops.dart';
import 'admin_people.dart';

enum AdminPage { dashboard, liveMap, drivers, passengers, rides, support, settings }

extension on AdminPage {
  String get label => switch (this) {
        AdminPage.dashboard => 'Dashboard',
        AdminPage.liveMap => 'Live map',
        AdminPage.drivers => 'Drivers',
        AdminPage.passengers => 'Users',
        AdminPage.rides => 'Rides',
        AdminPage.support => 'Support',
        AdminPage.settings => 'Fares & settings',
      };

  IconData get icon => switch (this) {
        AdminPage.dashboard => Icons.dashboard_outlined,
        AdminPage.liveMap => Icons.map_outlined,
        AdminPage.drivers => Icons.badge_outlined,
        AdminPage.passengers => Icons.people_outline,
        AdminPage.rides => Icons.route_outlined,
        AdminPage.support => Icons.support_agent,
        AdminPage.settings => Icons.tune,
      };
}

/// Control office: chaudi screen pe side rail, phone pe drawer.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminPage page = AdminPage.dashboard;

  void go(AdminPage p) => setState(() => page = p);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;
    int badge(AdminPage p) => switch (p) {
          AdminPage.drivers => store.pendingDrivers.length,
          AdminPage.support => store.openTickets,
          _ => 0,
        };

    Widget navItem(AdminPage p, {bool closeDrawer = false}) => ListTile(
          selected: p == page,
          selectedTileColor: AppColors.brand.withValues(alpha: 0.18),
          selectedColor: Colors.white,
          iconColor: Colors.white70,
          textColor: Colors.white70,
          leading: Icon(p.icon),
          title: Text(p.label),
          trailing: badge(p) > 0
              ? CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.brand,
                  child: Text('${badge(p)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.dark, fontWeight: FontWeight.w800)),
                )
              : null,
          onTap: () {
            if (closeDrawer) Navigator.pop(context);
            go(p);
          },
        );

    Widget nav({bool closeDrawer = false}) => Container(
          width: 250,
          color: AppColors.dark,
          child: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text('Go Ride',
                    style: TextStyle(color: AppColors.brand, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Control office', style: TextStyle(color: Colors.white54)),
              ),
              for (final p in AdminPage.values) navItem(p, closeDrawer: closeDrawer),
              const Spacer(),
              ListTile(
                iconColor: Colors.white70,
                textColor: Colors.white70,
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: store.adminLogout,
              ),
            ]),
          ),
        );

    final body = switch (page) {
      AdminPage.dashboard => AdminDashboard(onOpen: go),
      AdminPage.liveMap => const AdminLiveMap(),
      AdminPage.drivers => const AdminDrivers(),
      AdminPage.passengers => const AdminUsers(),
      AdminPage.rides => const AdminRides(),
      AdminPage.support => const AdminSupport(),
      AdminPage.settings => const AdminSettings(),
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      drawer: wide ? null : Drawer(child: nav(closeDrawer: true)),
      appBar: wide
          ? null
          : AppBar(title: Text(page.label), backgroundColor: AppColors.surface),
      body: Row(children: [
        if (wide) nav(),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text(page.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            Expanded(child: body),
          ]),
        ),
      ]),
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: child,
      );
}

class AdminDashboard extends StatelessWidget {
  final ValueChanged<AdminPage> onOpen;
  const AdminDashboard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tiles = [
      ('Rides (24 h)', '${store.ridesToday.length}', '${store.completedToday} completed · ${store.cancelledToday} cancelled', AdminPage.rides),
      ('Gross fares (24 h)', pkr(store.grossToday), 'Cash paid to drivers', AdminPage.rides),
      ('Commission (24 h)', pkr(store.commissionToday), '${store.settings.commissionPercent}% of completed rides', AdminPage.settings),
      ('Active rides', '${store.activeRides}', 'Searching or on trip now', AdminPage.rides),
      ('Drivers online', '${store.onlineDrivers.length}', 'of ${store.allDrivers.where((u) => u.isApprovedDriver).length} approved', AdminPage.liveMap),
      ('Pending drivers', '${store.pendingDrivers.length}', 'Waiting for document review', AdminPage.drivers),
      ('Open tickets', '${store.openTickets}', 'Waiting for a support reply', AdminPage.support),
      ('Users', '${store.users.length}', 'All accounts', AdminPage.passengers),
    ];
    final recent = store.rides.take(8).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1000 ? 4 : (c.maxWidth > 520 ? 2 : 1);
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (label, value, sub, page) in tiles)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onOpen(page),
                  child: AdminCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 20),
        const Text('Latest rides', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final r in recent)
              ListTile(
                title: Text('${r.from.name} → ${r.to.name}', overflow: TextOverflow.ellipsis),
                subtitle: Text('${store.userById(r.passengerId).name} · ${r.vehicleType.label} · ${timeAgo(r.createdAt)}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(pkr(r.finalFare), style: const TextStyle(fontWeight: FontWeight.w700)),
                  StatusChip(r.status.label, rideStatusColor(r.status)),
                ]),
                onTap: () => showRideDetails(context, r),
              ),
          ]),
        ),
      ],
    );
  }
}

class AdminLiveMap extends StatelessWidget {
  const AdminLiveMap({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final online = store.onlineDrivers;
    final byType = {for (final t in VehicleType.values) t: online.where((u) => u.driver!.vehicle.type == t).length};
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusChip('${online.length} online', Colors.green.shade700),
          for (final e in byType.entries) StatusChip('${e.key.label}: ${e.value}', AppColors.dark),
          StatusChip('${store.activeRides} active rides', Colors.blue.shade700),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: RideMap(zoom: 12, cars: [for (final d in online) d.driver!.location!]),
          ),
        ),
      ]),
    );
  }
}
