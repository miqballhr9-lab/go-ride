import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../screens/chat_screen.dart';
import '../screens/support/support_home.dart';
import '../screens/wallet_screen.dart';
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
  ServiceType? service;
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
      return okStatus && (service == null || r.service == service) && (type == null || r.vehicleType == type);
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
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
              label: const Text('All services'),
              selected: service == null,
              onSelected: (_) => setState(() {
                    service = null;
                    type = null;
                  })),
          for (final sv in ServiceType.values)
            ChoiceChip(
                label: Text(sv.label),
                selected: service == sv,
                onSelected: (_) => setState(() {
                      service = sv;
                      if (type != null && !sv.vehicles.contains(type)) type = null;
                    })),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('All vehicles'), selected: type == null, onSelected: (_) => setState(() => type = null)),
          for (final t in (service?.vehicles ?? VehicleType.values))
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
              '${r.id} · ${r.service.label} · ${r.vehicleType.label} · ${store.userById(r.passengerId).name}'
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
            ServiceInfo(ride: r),
            const SizedBox(height: 12),
            _line('Service', r.service.label),
            _line('Vehicle', r.vehicleType.label),
            _line('Payment', r.payment.label),
            _line('Distance', '${r.distanceKm.toStringAsFixed(1)} km'),
            _line('Passenger', '${p.name} · ${p.phone}'),
            _line('Driver', d == null ? '-' : '${d.name} · ${d.phone} · ${d.driver!.vehicle.plate}'),
            _line('Passenger offer', pkr(r.fare)),
            _line('Final fare', pkr(r.finalFare)),
            if (r.status == RideStatus.completed) _line('Commission', pkr(r.commission)),
            _line('Requested', '${hhmm(r.createdAt)} (${timeAgo(r.createdAt)})'),
            if (r.completedAt != null) _line('Completed', hhmm(r.completedAt!)),
            _line('City', r.city),
            if (r.scheduledAt != null) _line('Scheduled for', '${r.scheduledAt!.day}/${r.scheduledAt!.month} ${hhmm(r.scheduledAt!)}'),
            if (r.service == ServiceType.intercity) _line('Seats', '${r.seats}'),
            if (r.promoCode != null) _line('Promo', '${r.promoCode} · −${pkr(r.discount)} (passenger paid ${pkr(r.passengerPays)})'),
            if (r.refunded) _line('Refund', 'Refunded to passenger wallet'),
            if (r.cancelReason != null) _line('Cancelled', 'by ${r.cancelledBy}: ${r.cancelReason}'),
            if (r.driverRatingGiven != null)
              _line('Driver review', '★ ${r.driverRatingGiven}${r.driverReview.isEmpty ? '' : ' · ${r.driverReview}'}'),
            if (r.passengerRatingGiven != null)
              _line('Passenger review',
                  '★ ${r.passengerRatingGiven}${r.passengerReview.isEmpty ? '' : ' · ${r.passengerReview}'}'),
            if (r.comment.isNotEmpty) _line('Comment', r.comment),
            if (r.chat.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final m in r.chat)
                Text('${store.userById(m.senderId).name}: ${m.isCall ? '📞 ' : ''}${m.text}', style: const TextStyle(fontSize: 13)),
            ],
          ]),
        ),
      ),
      actions: [
        if (r.status == RideStatus.completed && !r.refunded)
          TextButton(
            onPressed: () async {
              final reason = await pickReason(ctx, 'Refund ${pkr(r.passengerPays)} to passenger wallet?', const [
                'Driver took a longer route',
                'Driver asked for extra money',
                'Ride did not happen',
                'Goodwill',
              ]);
              if (reason != null) {
                store.refundRide(r, r.passengerPays, reason);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Refund'),
          ),
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

// ================================================================ Payments

class AdminPayments extends StatelessWidget {
  const AdminPayments({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final today = store.transactions.where((t) => t.time.isAfter(since) && t.status == TxStatus.success);
    final topUps = today.where((t) => t.type == TxType.topUp).fold(0, (s, t) => s + t.amount);
    final commission = -today.where((t) => t.type == TxType.commission).fold(0, (s, t) => s + t.amount);
    final negative = store.allDrivers.where((u) => u.walletBalance < 0).toList();
    final pending = store.pendingTopUps;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _summary('Top-ups (24 h)', pkr(topUps)),
          _summary('Commission collected (24 h)', pkr(commission)),
          _summary('Drivers below zero', '${negative.length}'),
        ]),
        const SizedBox(height: 20),
        Text('Pending top-ups (${pending.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Text('Nothing to check', style: TextStyle(color: AppColors.muted))
        else
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final t in pending)
                ListTile(
                  title: Text('${store.userById(t.userId).name} · ${pkr(t.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${t.method} · ${t.note} · ${timeAgo(t.time)}'),
                  trailing: Wrap(spacing: 8, children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), foregroundColor: AppColors.danger),
                      onPressed: () => store.rejectTopUp(t),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                      onPressed: () => store.approveTopUp(t),
                      child: const Text('Approve'),
                    ),
                  ]),
                ),
            ]),
          ),
        const SizedBox(height: 20),
        Text('Driver withdrawals (${store.pendingWithdrawals.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (store.pendingWithdrawals.isEmpty)
          const Text('No withdrawal requests', style: TextStyle(color: AppColors.muted))
        else
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final t in store.pendingWithdrawals)
                ListTile(
                  title: Text('${store.userById(t.userId).name} · ${pkr(-t.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${t.method} ${t.note} · ${timeAgo(t.time)}'),
                  trailing: Wrap(spacing: 8, children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), foregroundColor: AppColors.danger),
                      onPressed: () => store.rejectWithdrawal(t),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                      onPressed: () => store.approveWithdrawal(t),
                      child: const Text('Mark paid'),
                    ),
                  ]),
                ),
            ]),
          ),
        if (negative.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Drivers with negative balance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final u in negative)
                ListTile(
                  title: Text(u.name),
                  subtitle: Text(u.phone),
                  trailing: Text(pkr(u.walletBalance),
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Latest transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (final t in store.transactions.take(40)) TransactionTile(t: t, who: store.userById(t.userId).name),
          ]),
        ),
      ],
    );
  }

  Widget _summary(String label, String value) => SizedBox(
        width: 240,
        child: AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// Support ki taraf se balance mein kami / bashi.
Future<void> showAdjustBalance(BuildContext context, AppUser u) async {
  final store = StoreScope.of(context);
  final amount = TextEditingController();
  final note = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Adjust balance · ${u.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Current balance: ${pkr(u.walletBalance)}'),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(labelText: 'Amount (use - to deduct)', prefixText: 'Rs '),
        ),
        const SizedBox(height: 8),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Reason')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            final a = int.tryParse(amount.text.trim());
            if (a == null || a == 0 || note.text.trim().isEmpty) return;
            store.adjustBalance(u, a, note.text.trim());
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  amount.dispose();
  note.dispose();
}

// ================================================================ Support

class AdminSupport extends StatefulWidget {
  const AdminSupport({super.key});

  @override
  State<AdminSupport> createState() => _AdminSupportState();
}

class _AdminSupportState extends State<AdminSupport> {
  TicketStatus filter = TicketStatus.open;
  bool mine = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.currentStaff!.name;
    final list = store.tickets
        .where((t) => t.status == filter && (!mine || t.assignedTo == me))
        .toList()
      ..sort((a, b) => (b.overdue ? 1 : 0) - (a.overdue ? 1 : 0));
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
          FilterChip(label: const Text('Assigned to me'), selected: mine, onSelected: (v) => setState(() => mine = v)),
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
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (t.overdue)
                        const StatusChip('Overdue', AppColors.danger)
                      else
                        Text(timeAgo(t.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      Text(t.assignedTo ?? 'Unassigned', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
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
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: t.assignedTo,
                hint: const Text('Assign'),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  for (final a in store.staff.where((a) => a.role == AdminRole.support || a.role == AdminRole.superAdmin))
                    DropdownMenuItem(value: a.name, child: Text(a.name)),
                ],
                onChanged: (v) => store.assignTicket(t, v),
              ),
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
  String city = 'Lahore';
  Set<ServiceType> services = {};
  bool _init = false;

  TextEditingController _ctrl(String key) => c.putIfAbsent(key, TextEditingController.new);

  /// Chune hue sheher ki settings form mein bharo.
  void _load() {
    final cd = StoreScope.of(context).cityOf(city);
    final s = cd.settings;
    for (final t in VehicleType.values) {
      _ctrl('base-${t.name}').text = '${s.baseFare[t]}';
      _ctrl('km-${t.name}').text = '${s.perKm[t]}';
      _ctrl('min-${t.name}').text = '${s.minFare[t]}';
    }
    _ctrl('commission').text = '${s.commissionPercent}';
    _ctrl('airport').text = '${cd.airportFee}';
    services = {...cd.services};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _load();
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
    final airport = _v('airport');
    if (commission == null || commission < 0 || commission > 50) {
      showSnack(context, 'Commission must be between 0 and 50%');
      return;
    }
    if (airport == null || airport < 0) {
      showSnack(context, 'Enter a valid airport fee');
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
    store.updateSettings(
      FareSettings(baseFare: base, perKm: km, minFare: min, commissionPercent: commission),
      city: city,
      airportFee: airport,
      services: services,
    );
    showSnack(context, '$city settings saved. New requests use these fares.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget field(String key, String label, {String? prefix = 'Rs ', String? suffix}) => SizedBox(
          width: 150,
          child: TextField(
            controller: c[key],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, prefixText: prefix, suffixText: suffix),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final name in store.cityData.keys)
            ChoiceChip(
              label: Text(name),
              selected: city == name,
              onSelected: (_) => setState(() {
                city = name;
                _load();
              }),
            ),
        ]),
        const SizedBox(height: 12),
        const Text('Recommended fare = base fare + (km × per km), never below the minimum. '
            'Intercity uses 60% of the per km rate. Passengers can offer down to 70% of the recommended fare.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Services in $city', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sv in ServiceType.values)
                FilterChip(
                  avatar: Icon(serviceIcon(sv), size: 16),
                  label: Text(sv.label),
                  selected: services.contains(sv),
                  onSelected: (on) => setState(() => on ? services.add(sv) : services.remove(sv)),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
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
            const Text('Commission and zones', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Commission is the share of each completed ride drivers pay to Go Ride. '
                'The airport fee is added when a trip starts or ends at the airport.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              field('commission', 'Commission', prefix: null, suffix: '%'),
              field('airport', 'Airport fee'),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            onPressed: _save,
            child: Text('Save $city settings'),
          ),
        ),
      ],
    );
  }
}
