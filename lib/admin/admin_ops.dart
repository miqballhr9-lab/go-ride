import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../screens/chat_screen.dart';
import '../screens/support/support_home.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_shell.dart';

// ================================================================ Rides

enum _RideFilter { all, active, completed, cancelled }

class AdminRides extends StatefulWidget {
  const AdminRides({super.key});

  @override
  State<AdminRides> createState() => _AdminRidesState();
}

class _AdminRidesState extends State<AdminRides> {
  _RideFilter filter = _RideFilter.all;
  VehicleType? type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.rides.where((r) {
      final okStatus = switch (filter) {
        _RideFilter.all => true,
        _RideFilter.active => r.status.isActive,
        _RideFilter.completed => r.status == RideStatus.completed,
        _RideFilter.cancelled => r.status == RideStatus.cancelled,
      };
      return okStatus && (type == null || r.vehicleType == type);
    }).take(100).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in _RideFilter.values)
            ChoiceChip(
              label: Text(f.name[0].toUpperCase() + f.name.substring(1)),
              selected: filter == f,
              onSelected: (_) => setState(() => filter = f),
            ),
          const SizedBox(width: 12),
          ChoiceChip(label: const Text('All types'), selected: type == null, onSelected: (_) => setState(() => type = null)),
          for (final t in VehicleType.values)
            ChoiceChip(label: Text(t.label), selected: type == t, onSelected: (_) => setState(() => type = t)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No rides', style: TextStyle(color: AppColors.muted))),
          )
        else
          RideTable(rides: list),
      ],
    );
  }
}

class RideTable extends StatelessWidget {
  final List<RideRequest> rides;
  const RideTable({super.key, required this.rides});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final r in rides)
          ListTile(
            title: Text('${r.from.name} → ${r.to.name}', overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${r.id} · ${r.vehicleType.label} · ${store.userById(r.passengerId).name}'
              '${r.driverId != null ? ' → ${store.userById(r.driverId!).name}' : ''} · ${timeAgo(r.createdAt)}',
              overflow: TextOverflow.ellipsis,
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
      ]),
    );
  }
}

void showRideDetails(BuildContext context, RideRequest r) {
  final store = StoreScope.of(context);
  final p = store.userById(r.passengerId);
  final d = r.driverId == null ? null : store.userById(r.driverId!);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Ride ${r.id}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatusChip(r.status.label, rideStatusColor(r.status)),
            const SizedBox(height: 12),
            RouteLines(from: r.from, to: r.to),
            const SizedBox(height: 12),
            _line('Type', r.vehicleType.label),
            _line('Distance', '${r.distanceKm.toStringAsFixed(1)} km'),
            _line('Passenger', '${p.name} · ${p.phone}'),
            _line('Driver', d == null ? '-' : '${d.name} · ${d.phone} · ${d.driver!.vehicle.plate}'),
            _line('Passenger offer', pkr(r.fare)),
            _line('Final fare', pkr(r.finalFare)),
            if (r.status == RideStatus.completed) _line('Commission', pkr(r.commission)),
            _line('Requested', '${hhmm(r.createdAt)} (${timeAgo(r.createdAt)})'),
            if (r.completedAt != null) _line('Completed', hhmm(r.completedAt!)),
            if (r.cancelReason != null) _line('Cancelled', 'by ${r.cancelledBy}: ${r.cancelReason}'),
            if (r.driverRatingGiven != null) _line('Driver rated', '★ ${r.driverRatingGiven}'),
            if (r.passengerRatingGiven != null) _line('Passenger rated', '★ ${r.passengerRatingGiven}'),
            if (r.comment.isNotEmpty) _line('Comment', r.comment),
            if (r.chat.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final m in r.chat)
                Text('${store.userById(m.senderId).name}: ${m.text}', style: const TextStyle(fontSize: 13)),
            ],
          ]),
        ),
      ),
      actions: [
        if (r.status.isActive)
          TextButton(
            onPressed: () {
              store.adminCancelRide(r);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel ride', style: TextStyle(color: AppColors.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

Widget _line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted))),
        Expanded(child: Text(v)),
      ]),
    );

// ================================================================ Support

class AdminSupport extends StatefulWidget {
  const AdminSupport({super.key});

  @override
  State<AdminSupport> createState() => _AdminSupportState();
}

class _AdminSupportState extends State<AdminSupport> {
  TicketStatus filter = TicketStatus.open;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.tickets.where((t) => t.status == filter).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(spacing: 8, children: [
          for (final s in TicketStatus.values)
            ChoiceChip(
              label: Text('${s.label} (${store.tickets.where((t) => t.status == s).length})'),
              selected: filter == s,
              onSelected: (_) => setState(() => filter = s),
            ),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No tickets', style: TextStyle(color: AppColors.muted))),
          )
        else
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final t in list)
                ListTile(
                  leading: Icon(t.role == AppMode.driver ? Icons.badge_outlined : Icons.person_outline),
                  title: Text('${t.category} · ${store.userById(t.userId).name}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.messages.last.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(timeAgo(t.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => AdminTicketScreen(ticket: t))),
                ),
            ]),
          ),
      ],
    );
  }
}

const _templates = [
  'We are sorry for the trouble. We are looking into this and will update you shortly.',
  'We have contacted the driver and asked them to get in touch with you.',
  'We have issued a warning to the driver. Thank you for reporting this.',
  'Your issue has been resolved. Please let us know if you need anything else.',
];

class AdminTicketScreen extends StatefulWidget {
  final SupportTicket ticket;
  const AdminTicketScreen({super.key, required this.ticket});

  @override
  State<AdminTicketScreen> createState() => _AdminTicketScreenState();
}

class _AdminTicketScreenState extends State<AdminTicketScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = widget.ticket;
    final u = store.userById(t.userId);
    final ride = store.rideById(t.rideId);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('${t.id} · ${t.category}'),
        actions: [
          if (t.status != TicketStatus.closed)
            TextButton(onPressed: () => store.closeTicket(t), child: const Text('Close ticket')),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AdminCard(
            child: Row(children: [
              Avatar(u.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u.name} (${t.role == AppMode.driver ? 'driver' : 'passenger'})',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(u.phone, style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
              StatusChip(t.status.label, ticketColor(t.status)),
              if (ride != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  onPressed: () => showRideDetails(context, ride),
                  child: const Text('View ride'),
                ),
              ],
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in t.messages)
                ChatBubble(
                  text: m.text,
                  mine: m.fromSupport,
                  time: m.time,
                  label: m.fromSupport ? 'Support' : u.name,
                ),
            ],
          ),
        ),
        if (t.status != TicketStatus.closed) ...[
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final tpl in _templates)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(tpl.length > 40 ? '${tpl.substring(0, 40)}…' : tpl),
                      onPressed: () => ctrl.text = tpl,
                    ),
                  ),
              ],
            ),
          ),
          MessageInput(
            controller: ctrl,
            hint: 'Reply to ${u.name}',
            onSend: (text) {
              if (text.trim().isEmpty) return;
              store.adminReplyTicket(t, text.trim());
              ctrl.clear();
            },
          ),
        ],
      ]),
    );
  }
}

// ================================================================ Settings

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final Map<String, TextEditingController> c = {};
  bool _init = false;

  TextEditingController _ctrl(String key, int value) =>
      c.putIfAbsent(key, () => TextEditingController(text: '$value'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    final s = StoreScope.of(context).settings;
    for (final t in VehicleType.values) {
      _ctrl('base-${t.name}', s.baseFare[t]!);
      _ctrl('km-${t.name}', s.perKm[t]!);
      _ctrl('min-${t.name}', s.minFare[t]!);
    }
    _ctrl('commission', s.commissionPercent);
    _init = true;
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  int? _v(String key) => int.tryParse(c[key]!.text.trim());

  void _save() {
    final store = StoreScope.of(context);
    final commission = _v('commission');
    if (commission == null || commission < 0 || commission > 50) {
      showSnack(context, 'Commission must be between 0 and 50%');
      return;
    }
    final base = <VehicleType, int>{}, km = <VehicleType, int>{}, min = <VehicleType, int>{};
    for (final t in VehicleType.values) {
      final b = _v('base-${t.name}'), k = _v('km-${t.name}'), m = _v('min-${t.name}');
      if (b == null || k == null || m == null || b < 0 || k <= 0 || m <= 0) {
        showSnack(context, 'Check the values for ${t.label}');
        return;
      }
      base[t] = b;
      km[t] = k;
      min[t] = m;
    }
    store.updateSettings(FareSettings(baseFare: base, perKm: km, minFare: min, commissionPercent: commission));
    showSnack(context, 'Settings saved. New ride requests use these fares.');
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String key, String label) => SizedBox(
          width: 150,
          child: TextField(
            controller: c[key],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, prefixText: key == 'commission' ? null : 'Rs '),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Recommended fare = base fare + (km × per km), never below the minimum. '
            'Passengers can offer down to 70% of the recommended fare.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        for (final t in VehicleType.values) ...[
          AdminCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                field('base-${t.name}', 'Base fare'),
                field('km-${t.name}', 'Per km'),
                field('min-${t.name}', 'Minimum fare'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Commission', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Percentage of each completed ride that drivers pay to Go Ride.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            SizedBox(
              width: 150,
              child: TextField(
                controller: c['commission'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Commission', suffixText: '%'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            onPressed: _save,
            child: const Text('Save settings'),
          ),
        ),
      ],
    );
  }
}
