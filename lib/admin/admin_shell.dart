import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_more.dart';
import 'admin_ops.dart';
import 'admin_people.dart';

enum AdminPage { dashboard, liveMap, drivers, passengers, rides, payments, support, safety, marketing, reports, settings, audit, staff }

extension on AdminPage {
  String get label => switch (this) {
    AdminPage.dashboard => 'Dashboard',
    AdminPage.liveMap => 'Live map',
    AdminPage.drivers => 'Drivers',
    AdminPage.passengers => 'Users',
    AdminPage.rides => 'Rides',
    AdminPage.payments => 'Payments',
    AdminPage.support => 'Support',
    AdminPage.safety => 'Safety',
    AdminPage.marketing => 'Marketing',
    AdminPage.reports => 'Reports',
    AdminPage.settings => 'Cities & fares',
    AdminPage.audit => 'Audit log',
    AdminPage.staff => 'Staff',
  };

  IconData get icon => switch (this) {
    AdminPage.dashboard => Icons.dashboard_outlined,
    AdminPage.liveMap => Icons.map_outlined,
    AdminPage.drivers => Icons.badge_outlined,
    AdminPage.passengers => Icons.people_outline,
    AdminPage.rides => Icons.route_outlined,
    AdminPage.payments => Icons.payments_outlined,
    AdminPage.support => Icons.support_agent,
    AdminPage.safety => Icons.shield_outlined,
    AdminPage.marketing => Icons.campaign_outlined,
    AdminPage.reports => Icons.bar_chart,
    AdminPage.settings => Icons.tune,
    AdminPage.audit => Icons.history_edu,
    AdminPage.staff => Icons.manage_accounts_outlined,
  };
}

String adminPageLabel(AdminPage p) => p.label;

/// Har role ko sirf apne kaam ke pages.
bool canSee(AdminRole role, AdminPage p) => switch (role) {
  AdminRole.superAdmin => true,
  AdminRole.support => const {
      AdminPage.dashboard, AdminPage.liveMap, AdminPage.passengers, AdminPage.rides,
      AdminPage.support, AdminPage.safety,
    }.contains(p),
  AdminRole.verification => const {AdminPage.dashboard, AdminPage.drivers, AdminPage.safety}.contains(p),
  AdminRole.finance => const {
      AdminPage.dashboard, AdminPage.rides, AdminPage.payments, AdminPage.reports, AdminPage.marketing,
    }.contains(p),
};

/// Control office: chaudi screen pe side rail, phone pe drawer.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminPage page = AdminPage.dashboard;
  final List<AdminPage> _history = [];

  void go(AdminPage p) {
    if (p == page) return;
    if (!canSee(StoreScope.of(context).currentStaff!.role, p)) {
      showSnack(context, 'Your role cannot open ${p.label}');
      return;
    }
    setState(() {
      _history.add(page);
      page = p;
    });
  }

  /// Pichla admin page; Dashboard se wapas jahan se Control office khola tha.
  void back() {
    if (_history.isNotEmpty) {
      setState(() => page = _history.removeLast());
    } else {
      StoreScope.of(context).adminLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;
    final staff = store.currentStaff!;
    final pages = AdminPage.values.where((p) => canSee(staff.role, p)).toList();
    int badge(AdminPage p) => switch (p) {
      AdminPage.drivers => store.pendingDrivers.length,
      AdminPage.support => store.openTickets,
      AdminPage.payments => store.pendingTopUps.length + store.pendingWithdrawals.length,
      AdminPage.safety => store.openAlerts,
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
              child: Text(
                '${badge(p)}',
                style: const TextStyle(fontSize: 11, color: AppColors.dark, fontWeight: FontWeight.w800),
              ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Align(alignment: Alignment.centerLeft, child: MikLogo(size: 36, nameColor: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Control office · ${staff.name}', style: const TextStyle(color: Colors.white54)),
            ),
            Expanded(
              child: ListView(children: [for (final p in pages) navItem(p, closeDrawer: closeDrawer)]),
            ),
            ListTile(
              iconColor: Colors.white70,
              textColor: Colors.white70,
              leading: const Icon(Icons.switch_account_outlined),
              title: const Text('Switch role (demo)'),
              onTap: () async {
                if (closeDrawer) Navigator.pop(context);
                final a = await showModalBottomSheet<StaffAccount>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final a in store.staff)
                        ListTile(
                          leading: Avatar(a.name, size: 36),
                          title: Text(a.name),
                          subtitle: Text(a.role.label),
                          onTap: () => Navigator.pop(ctx, a),
                        ),
                    ]),
                  ),
                );
                if (a == null) return;
                store.adminLogin(a.username, a.password);
                setState(() {
                  page = AdminPage.dashboard;
                  _history.clear();
                });
              },
            ),
            ListTile(
              iconColor: Colors.white70,
              textColor: Colors.white70,
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: store.adminLogout,
            ),
          ],
        ),
      ),
    );

    final body = switch (page) {
      AdminPage.dashboard => AdminDashboard(onOpen: go),
      AdminPage.liveMap => const AdminLiveMap(),
      AdminPage.drivers => const AdminDrivers(),
      AdminPage.passengers => const AdminUsers(),
      AdminPage.rides => const AdminRides(),
      AdminPage.payments => const AdminPayments(),
      AdminPage.support => const AdminSupport(),
      AdminPage.safety => const AdminSafety(),
      AdminPage.marketing => const AdminMarketing(),
      AdminPage.reports => const AdminReports(),
      AdminPage.settings => const AdminSettings(),
      AdminPage.audit => const AdminAudit(),
      AdminPage.staff => const AdminStaff(),
    };

    return PopScope(
      // Phone ka back button bhi isi tarah kaam kare.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        drawer: wide ? null : Drawer(child: nav(closeDrawer: true)),
        appBar: wide
            ? null
            : AppBar(
                leadingWidth: 96,
                leading: BackMenuLeading(onBack: back),
                title: Text(page.label),
                backgroundColor: AppColors.surface,
                actions: [
                  IconButton(tooltip: 'Sign out', onPressed: store.adminLogout, icon: const Icon(Icons.logout)),
                ],
                // Chhoti screen pe saare pages upar tabs mein.
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        for (final p in pages)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              avatar: Icon(p.icon, size: 16),
                              label: Text(badge(p) > 0 ? '${p.label} (${badge(p)})' : p.label),
                              selected: p == page,
                              onSelected: (_) => go(p),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        body: Row(
          children: [
            if (wide) nav(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 24, 0),
                      child: Row(
                        children: [
                          IconButton(tooltip: 'Back', onPressed: back, icon: const Icon(Icons.arrow_back)),
                          const SizedBox(width: 4),
                          Text(page.label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          StatusChip('${staff.name} · ${staff.role.label}', AppColors.dark),
                        ],
                      ),
                    ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
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
      (
        'Rides (24 h)',
        '${store.ridesToday.length}',
        '${store.completedToday} completed · ${store.cancelledToday} cancelled',
        AdminPage.rides,
      ),
      ('Gross fares (24 h)', pkr(store.grossToday), 'Cash paid to drivers', AdminPage.rides),
      (
        'Commission (24 h)',
        pkr(store.commissionToday),
        '${store.settings.commissionPercent}% of completed rides',
        AdminPage.settings,
      ),
      ('Active rides', '${store.activeRides}', 'Searching or on trip now', AdminPage.rides),
      (
        'Drivers online',
        '${store.onlineDrivers.length}',
        'of ${store.allDrivers.where((u) => u.isApprovedDriver).length} approved',
        AdminPage.liveMap,
      ),
      ('Pending drivers', '${store.pendingDrivers.length}', 'Waiting for document review', AdminPage.drivers),
      ('Open tickets', '${store.openTickets}', 'Waiting for a support reply', AdminPage.support),
      ('Open SOS alerts', '${store.openAlerts}', 'Need action now', AdminPage.safety),
      ('Pending top-ups', '${store.pendingTopUps.length}', 'Bank transfers to check', AdminPage.payments),
      (
        'Courier · Freight (24 h)',
        '${store.ridesToday.where((r) => r.service == ServiceType.courier).length} · ${store.ridesToday.where((r) => r.service == ServiceType.freight).length}',
        'Parcel and cargo orders',
        AdminPage.rides,
      ),
      ('Users', '${store.users.length}', 'All accounts', AdminPage.passengers),
    ];
    final recent = store.rides.take(8).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 1000 ? 4 : (c.maxWidth > 520 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (label, value, sub, page) in tiles)
                  SizedBox(
                    width: w,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onOpen(page),
                      child: AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                            Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('Latest rides', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final r in recent)
                ListTile(
                  title: Text('${r.from.name} → ${r.to.name}', overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${store.userById(r.passengerId).name} · ${r.service.label} · ${r.vehicleType.label} · ${timeAgo(r.createdAt)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(pkr(r.finalFare), style: const TextStyle(fontWeight: FontWeight.w700)),
                      StatusChip(r.status.label, rideStatusColor(r.status)),
                    ],
                  ),
                  onTap: () => showRideDetails(context, r),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminLiveMap extends StatefulWidget {
  const AdminLiveMap({super.key});

  @override
  State<AdminLiveMap> createState() => _AdminLiveMapState();
}

class _AdminLiveMapState extends State<AdminLiveMap> {
  String city = 'Lahore';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final online = store.onlineDrivers.where((u) => u.city == city).toList();
    final byType = {for (final t in VehicleType.values) t: online.where((u) => u.driver!.vehicle.type == t).length};
    final sos = store.alerts.where((a) => !a.resolved).length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in store.cityData.keys)
              ChoiceChip(label: Text(c), selected: c == city, onSelected: (_) => setState(() => city = c)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip('${online.length} online', Colors.green.shade700),
              for (final e in byType.entries)
                if (e.value > 0) StatusChip('${e.key.label}: ${e.value}', AppColors.dark),
              StatusChip('${store.rides.where((r) => r.status.isActive && r.city == city).length} active rides',
                  Colors.blue.shade700),
              if (sos > 0) StatusChip('$sos open SOS', AppColors.danger),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RideMap(
                zoom: 12,
                center: store.cityOf(city).center,
                cars: [for (final d in online) d.driver!.location!],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
