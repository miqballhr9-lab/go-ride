import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_ops.dart';
import 'admin_people.dart';
import 'admin_shell.dart';

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    );

Widget _empty(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(t, style: const TextStyle(color: AppColors.muted)),
    );

String _dt(DateTime t) => '${t.day}/${t.month}/${t.year} ${hhmm(t)}';

// ================================================================ Safety

class AdminSafety extends StatelessWidget {
  const AdminSafety({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final open = store.alerts.where((a) => !a.resolved).toList();
    final closed = store.alerts.where((a) => a.resolved).take(10).toList();
    final flags = store.fraudFlags;
    final licenses = store.allDrivers
        .where((u) => u.isApprovedDriver && (u.driver!.licenseExpired || u.driver!.licenseExpiringSoon))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        _title('Open SOS alerts (${open.length})'),
        if (open.isEmpty) _empty('No open alerts'),
        for (final a in open) _AlertCard(alert: a),
        _title('Suspicious accounts (${flags.length})'),
        if (flags.isEmpty) _empty('Nothing suspicious right now'),
        if (flags.isNotEmpty)
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (u, reason) in flags)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(reason),
                  trailing: u.suspended ? const StatusChip('Suspended', AppColors.danger) : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => u.driver != null ? DriverDetailScreen(user: u) : UserDetailScreen(user: u)),
                  ),
                ),
            ]),
          ),
        _title('Driving licenses to renew (${licenses.length})'),
        if (licenses.isEmpty) _empty('All licenses are valid'),
        if (licenses.isNotEmpty)
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final u in licenses)
                ListTile(
                  title: Text(u.name),
                  subtitle: Text('License ${u.driver!.licenseNo}'),
                  trailing: StatusChip(
                    u.driver!.licenseExpired
                        ? 'Expired ${u.driver!.licenseExpiry.day}/${u.driver!.licenseExpiry.month}'
                        : 'Expires ${u.driver!.licenseExpiry.day}/${u.driver!.licenseExpiry.month}',
                    u.driver!.licenseExpired ? AppColors.danger : AppColors.warning,
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverDetailScreen(user: u))),
                ),
            ]),
          ),
        if (closed.isNotEmpty) ...[
          _title('Resolved alerts'),
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final a in closed)
                ListTile(
                  dense: true,
                  title: Text('${store.userById(a.userId).name} · ride ${a.rideId}'),
                  subtitle: Text('${_dt(a.time)} · ${a.note}'),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final SafetyAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.userById(alert.userId);
    final ride = store.rideById(alert.rideId);
    final driver = ride?.driverId == null ? null : store.userById(ride!.driverId!);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sos, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text('SOS from ${u.name} · ${timeAgo(alert.time)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Phone: ${u.phone}'),
        if (ride != null) Text('Ride ${ride.id}: ${ride.from.name} → ${ride.to.name} · ${ride.status.label}'),
        if (driver != null) Text('Driver: ${driver.name} · ${driver.phone} · ${driver.driver!.vehicle.plate}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (ride != null)
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => showRideDetails(context, ride),
              child: const Text('View ride'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () async {
              final note = await pickReason(context, 'How was it resolved?', const [
                'Called passenger, all safe',
                'Called driver, all safe',
                'Police informed (15)',
                'False alarm',
              ]);
              if (note != null) store.resolveAlert(alert, note);
            },
            child: const Text('Resolve'),
          ),
        ]),
      ]),
    );
  }
}

// ================================================================ Marketing

class AdminMarketing extends StatefulWidget {
  const AdminMarketing({super.key});

  @override
  State<AdminMarketing> createState() => _AdminMarketingState();
}

class _AdminMarketingState extends State<AdminMarketing> {
  final title = TextEditingController();
  final body = TextEditingController();
  Audience audience = Audience.everyone;
  late final banner = TextEditingController(text: StoreScope.of(context).bannerText);
  late bool bannerOn = StoreScope.of(context).bannerActive;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    banner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Row(children: [
          Expanded(child: _title('Promo codes')),
          TextButton.icon(onPressed: () => _newPromo(context), icon: const Icon(Icons.add), label: const Text('New code')),
        ]),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final p in store.promos)
              ListTile(
                title: Text(p.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                subtitle: Text('${p.summary} · used ${p.used}/${p.maxUses} · '
                    '${p.expires.isBefore(now) ? 'expired' : 'until ${p.expires.day}/${p.expires.month}'}'),
                trailing: Switch(
                  value: p.active && p.expires.isAfter(now),
                  onChanged: p.expires.isBefore(now) ? null : (v) => store.setPromoActive(p, v),
                ),
              ),
          ]),
        ),
        Row(children: [
          Expanded(child: _title('Driver bonuses')),
          TextButton.icon(onPressed: () => _newBonus(context), icon: const Icon(Icons.add), label: const Text('New bonus')),
        ]),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final i in store.incentives)
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(i.title),
                subtitle: Text('${i.targetRides} rides → ${pkr(i.reward)} · ${i.vehicleType?.label ?? 'All vehicles'} · '
                    '${i.validUntil.isBefore(now) ? 'ended' : 'until ${_dt(i.validUntil)}'} · paid to ${i.paidTo.length}'),
              ),
          ]),
        ),
        _title('Send a notification'),
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, children: [
              for (final a in [Audience.everyone, Audience.passengers, Audience.drivers])
                ChoiceChip(label: Text(a.label), selected: audience == a, onSelected: (_) => setState(() => audience = a)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: body, maxLines: 2, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
                onPressed: () {
                  if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
                  store.broadcast(audience, title.text.trim(), body.text.trim());
                  title.clear();
                  body.clear();
                  showSnack(context, 'Notification sent to ${audience.label.toLowerCase()}');
                },
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ),
          ]),
        ),
        _title('Recent notifications'),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final n in store.notifications.where((n) => n.audience != Audience.user).take(8))
              ListTile(
                dense: true,
                title: Text(n.title),
                subtitle: Text('${n.audience.label} · ${timeAgo(n.time)} · ${n.body}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
        _title('Passenger app banner'),
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: banner, decoration: const InputDecoration(labelText: 'Banner text')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: bannerOn,
              onChanged: (v) => setState(() => bannerOn = v),
              title: const Text('Show on passenger home'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
                onPressed: () {
                  store.setBanner(banner.text.trim(), bannerOn);
                  showSnack(context, 'Banner saved');
                },
                child: const Text('Save banner'),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _newPromo(BuildContext context) async {
    final store = StoreScope.of(context);
    final code = TextEditingController();
    final value = TextEditingController(text: '20');
    final uses = TextEditingController(text: '100');
    var percent = true;
    var days = 7;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New promo code'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code', hintText: 'SUMMER25'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                ChoiceChip(label: const Text('% off'), selected: percent, onSelected: (_) => setD(() => percent = true)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Rs off'), selected: !percent, onSelected: (_) => setD(() => percent = false)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: percent ? 'Percent (max Rs 300 off)' : 'Amount (Rs)'),
              ),
              const SizedBox(height: 8),
              TextField(controller: uses, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max uses')),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: days,
                decoration: const InputDecoration(labelText: 'Valid for'),
                items: [for (final d in [1, 3, 7, 30]) DropdownMenuItem(value: d, child: Text('$d day${d > 1 ? 's' : ''}'))],
                onChanged: (v) => days = v!,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                final v = int.tryParse(value.text.trim());
                final u = int.tryParse(uses.text.trim());
                final c = code.text.trim().toUpperCase();
                if (c.length < 3 || v == null || v <= 0 || u == null || u <= 0) return;
                if (percent && v > 100) return;
                if (store.promos.any((p) => p.code == c)) return;
                store.createPromo(PromoCode(
                  code: c,
                  percent: percent ? v : 0,
                  fixed: percent ? 0 : v,
                  maxUses: u,
                  expires: DateTime.now().add(Duration(days: days)),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    value.dispose();
    uses.dispose();
  }

  Future<void> _newBonus(BuildContext context) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: 'Complete 5 rides today');
    final target = TextEditingController(text: '5');
    final reward = TextEditingController(text: '500');
    VehicleType? type;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New driver bonus'),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rides to complete (24 h)')),
              const SizedBox(height: 8),
              TextField(controller: reward, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reward (Rs)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<VehicleType?>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'For'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All vehicles')),
                  for (final t in VehicleType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setD(() => type = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                final t = int.tryParse(target.text.trim());
                final r = int.tryParse(reward.text.trim());
                if (name.text.trim().isEmpty || t == null || t <= 0 || r == null || r <= 0) return;
                store.createIncentive(Incentive(
                  id: 'I${DateTime.now().millisecondsSinceEpoch}',
                  title: name.text.trim(),
                  vehicleType: type,
                  targetRides: t,
                  reward: r,
                  validUntil: DateTime.now().add(const Duration(hours: 24)),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    target.dispose();
    reward.dispose();
  }
}

// ================================================================ Reports

class AdminReports extends StatelessWidget {
  const AdminReports({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = store.ridesToday.toList();
    final done = today.where((r) => r.status == RideStatus.completed).toList();

    // Pichle 24 ghante: har ghante ki rides (purane se naye).
    final perHour = List.filled(24, 0);
    for (final r in today) {
      final h = now.difference(r.createdAt).inHours;
      if (h >= 0 && h < 24) perHour[23 - h]++;
    }
    final byService = {
      for (final s in ServiceType.values) s: done.where((r) => r.service == s).fold(0, (a, r) => a + r.finalFare),
    };
    final drivers = <String, (int, int, int)>{};
    for (final r in done) {
      final (n, fares, com) = drivers[r.driverId!] ?? (0, 0, 0);
      drivers[r.driverId!] = (n + 1, fares + r.finalFare, com + r.commission);
    }
    final top = drivers.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          _stat('Rides (24 h)', '${today.length}'),
          _stat('Completed', '${done.length}'),
          _stat('Gross fares', pkr(store.grossToday)),
          _stat('Commission', pkr(store.commissionToday)),
          _stat('Promo cost', pkr(done.fold(0, (a, r) => a + r.discount))),
          _stat('Refunds', pkr(-store.transactions.where((t) => t.type == TxType.refund).fold(0, (a, t) => a - t.amount))),
        ]),
        _title('Ride requests per hour (last 24 hours)'),
        AdminCard(child: _HourChart(values: perHour, now: now)),
        _title('Completed fares by service (24 h)'),
        AdminCard(
          child: Column(children: [
            for (final e in byService.entries)
              _HBar(label: e.key.label, value: e.value, max: byService.values.fold(1, (a, b) => a > b ? a : b)),
          ]),
        ),
        Row(children: [
          Expanded(child: _title('Top drivers (24 h)')),
          TextButton.icon(
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export rides (CSV)'),
          ),
        ]),
        AdminCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Driver')),
                DataColumn(label: Text('Rides'), numeric: true),
                DataColumn(label: Text('Fares'), numeric: true),
                DataColumn(label: Text('Commission'), numeric: true),
              ],
              rows: [
                for (final e in top.take(10))
                  DataRow(cells: [
                    DataCell(Text(store.userById(e.key).name)),
                    DataCell(Text('${e.value.$1}')),
                    DataCell(Text(pkr(e.value.$2))),
                    DataCell(Text(pkr(e.value.$3))),
                  ]),
              ],
            ),
          ),
        ),
        _title('Bus bookings (${store.busBookings.where((b) => !b.cancelled).length})'),
        if (store.busBookings.isEmpty) _empty('No bus tickets booked yet'),
        if (store.busBookings.isNotEmpty)
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final b in store.busBookings.take(20))
                Builder(builder: (_) {
                  final t = store.busTripById(b.tripId);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.directions_bus_outlined),
                    title: Text('${t.fromCity} → ${t.toCity} · ${t.operator} · ${b.seats} seat${b.seats > 1 ? 's' : ''}'),
                    subtitle: Text('${store.userById(b.userId).name} · ${_dt(t.departs)} · ${b.payment.label}'),
                    trailing: b.cancelled
                        ? const StatusChip('Cancelled', AppColors.danger)
                        : Text(pkr(b.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }),
            ]),
          ),
      ],
    );
  }

  Widget _stat(String label, String value) => SizedBox(
        width: 180,
        child: AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      );

  void _exportCsv(BuildContext context) {
    final store = StoreScope.of(context);
    final b = StringBuffer('id,date,city,service,vehicle,passenger,driver,from,to,status,fare,discount,commission,payment\n');
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    for (final r in store.rides.where((r) => !r.status.isActive)) {
      b.writeln([
        r.id,
        r.createdAt.toIso8601String().substring(0, 16),
        r.city,
        r.service.label,
        r.vehicleType.label,
        q(store.userById(r.passengerId).name),
        q(r.driverId == null ? '' : store.userById(r.driverId!).name),
        q(r.from.name),
        q(r.to.name),
        r.status.label,
        r.finalFare,
        r.discount,
        r.commission,
        r.payment.label,
      ].join(','));
    }
    final csv = b.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rides CSV'),
        content: SizedBox(
          width: 640,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (ctx.mounted) showSnack(ctx, 'Copied. Paste it into Excel or Google Sheets.');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

/// Ek rang ki bars, har bar pe hover se value. Halki grid, ek hi axis.
class _HourChart extends StatelessWidget {
  final List<int> values;
  final DateTime now;
  const _HourChart({required this.values, required this.now});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold(1, (a, b) => a > b ? a : b);
    final top = ((maxV + 1) / 2).ceil() * 2; // saaf ginti wala upar ka nishan
    const h = 160.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: h + 20,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 28,
            height: h,
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$top', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              Text('${top ~/ 2}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const Text('0', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(children: [
              // Grid lines
              for (final f in [0.0, 0.5, 1.0])
                Positioned(
                  top: h * f,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: const Color(0xFFE5E7EB)),
                ),
              SizedBox(
                height: h,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 24; i++)
                    Expanded(
                      child: Tooltip(
                        message: '${_hourLabel(i)}: ${values[i]} request${values[i] == 1 ? '' : 's'}',
                        child: Container(
                          height: h, // poori unchai hover ke liye
                          alignment: Alignment.bottomCenter,
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: values[i] == 0 ? 0 : (h * values[i] / top).clamp(2, h),
                            decoration: const BoxDecoration(
                              color: AppColors.dark,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Positioned(
                top: h + 4,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_hourLabel(0), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text(_hourLabel(12), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const Text('now', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  String _hourLabel(int i) => hhmm(DateTime(now.year, now.month, now.day, now.hour).subtract(Duration(hours: 23 - i)));
}

class _HBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  const _HBar({required this.label, required this.value, required this.max});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: value == 0 ? 0 : (c.maxWidth * value / max).clamp(2, c.maxWidth),
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(pkr(value),
                textAlign: TextAlign.right, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
      );
}

// ================================================================ Audit log

class AdminAudit extends StatefulWidget {
  const AdminAudit({super.key});

  @override
  State<AdminAudit> createState() => _AdminAuditState();
}

class _AdminAuditState extends State<AdminAudit> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = query.toLowerCase();
    final list = store.auditLog
        .where((e) => q.isEmpty || '${e.staff} ${e.action} ${e.target}'.toLowerCase().contains(q))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        const Text('Every action taken by control office staff, newest first.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by staff, action or name'),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nothing found')),
            for (final e in list)
              ListTile(
                dense: true,
                leading: const Icon(Icons.history_edu, size: 20),
                title: Text('${e.action} · ${e.target}'),
                subtitle: Text('${e.staff} · ${_dt(e.time)}'),
              ),
          ]),
        ),
      ],
    );
  }
}

// ================================================================ Staff

class AdminStaff extends StatelessWidget {
  const AdminStaff({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Row(children: [
          Expanded(child: _title('Control office staff')),
          TextButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt), label: const Text('Add staff')),
        ]),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final a in store.staff)
              ListTile(
                leading: Avatar(a.name, size: 36),
                title: Text(a.name),
                subtitle: Text('Username: ${a.username}'),
                trailing: StatusChip(a.role.label, AppColors.dark),
              ),
          ]),
        ),
        _title('What each role can open'),
        AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final r in AdminRole.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${r.label}: ${AdminPage.values.where((p) => canSee(r, p)).map(adminPageLabel).join(', ')}'),
              ),
          ]),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final store = StoreScope.of(context);
    final name = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController();
    var role = AdminRole.support;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add staff'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: user, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 8),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 8),
              DropdownButtonFormField<AdminRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [for (final r in AdminRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
                onChanged: (v) => setD(() => role = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                final u = user.text.trim();
                if (name.text.trim().isEmpty || u.isEmpty || pass.text.length < 6) return;
                if (store.staff.any((a) => a.username == u)) return;
                store.addStaff(StaffAccount(u, pass.text, name.text.trim(), role));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    user.dispose();
    pass.dispose();
  }
}
