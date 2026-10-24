import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// Courier: receiver aur parcel ki maloomat.
Future<ParcelDetails?> editParcel(BuildContext context, ParcelDetails? current, VehicleType type) {
  return showModalBottomSheet<ParcelDetails>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ParcelForm(current: current, type: type),
  );
}

class _ParcelForm extends StatefulWidget {
  final ParcelDetails? current;
  final VehicleType type;
  const _ParcelForm({this.current, required this.type});

  @override
  State<_ParcelForm> createState() => _ParcelFormState();
}

class _ParcelFormState extends State<_ParcelForm> {
  late final name = TextEditingController(text: widget.current?.receiverName);
  late final phone = TextEditingController(text: widget.current?.receiverPhone.replaceFirst('+92', ''));
  late final desc = TextEditingController(text: widget.current?.description);
  late ParcelSize size = widget.current?.size ?? ParcelSize.small;
  late bool fragile = widget.current?.fragile ?? false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizes = widget.type == VehicleType.moto ? [ParcelSize.small, ParcelSize.medium] : ParcelSize.values;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Parcel details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Receiver name')),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Receiver phone', prefixText: '+92  '),
          ),
          const SizedBox(height: 10),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'What are you sending?')),
          const SizedBox(height: 12),
          const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in sizes)
              ChoiceChip(
                label: Text('${s.label} · ${s.description}${s.surcharge > 0 ? ' (+Rs ${s.surcharge})' : ''}'),
                selected: size == s,
                onSelected: (_) => setState(() => size = s),
              ),
          ]),
          if (widget.type == VehicleType.moto)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Large parcels need Ride Mini.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: fragile,
            onChanged: (v) => setState(() => fragile = v),
            title: const Text('Fragile, handle with care'),
          ),
          if (error != null) Text(error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final digits = phone.text.replaceAll(RegExp(r'\D'), '');
              if (name.text.trim().length < 2 || digits.length != 10 || desc.text.trim().isEmpty) {
                setState(() => error = 'Enter receiver name, a valid phone number and what you are sending');
                return;
              }
              Navigator.pop(
                context,
                ParcelDetails(
                  receiverName: name.text.trim(),
                  receiverPhone: '+92$digits',
                  size: size,
                  description: desc.text.trim(),
                  fragile: fragile,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}

/// Freight: saman, wazan aur mazdoor.
Future<FreightDetails?> editFreight(BuildContext context, FreightDetails? current, VehicleType type) {
  return showModalBottomSheet<FreightDetails>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FreightForm(current: current, type: type),
  );
}

class _FreightForm extends StatefulWidget {
  final FreightDetails? current;
  final VehicleType type;
  const _FreightForm({this.current, required this.type});

  @override
  State<_FreightForm> createState() => _FreightFormState();
}

class _FreightFormState extends State<_FreightForm> {
  late final cargo = TextEditingController(text: widget.current?.cargo);
  late final weight = TextEditingController(text: widget.current?.weightKg.toString());
  late int helpers = widget.current?.helpers ?? 0;
  String? error;

  @override
  void dispose() {
    cargo.dispose();
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Cargo details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: cargo,
            decoration: const InputDecoration(labelText: 'What are you moving?', hintText: 'Furniture, fridge, boxes…'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: weight,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Approximate weight',
              suffixText: 'kg',
              helperText: '${widget.type.label} carries up to ${widget.type.maxKg} kg',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(
              child: Text('Loading helpers (Rs $helperFee each)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              onPressed: helpers > 0 ? () => setState(() => helpers--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$helpers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            IconButton(
              onPressed: helpers < 4 ? () => setState(() => helpers++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          if (error != null) Text(error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final w = int.tryParse(weight.text.trim());
              if (cargo.text.trim().isEmpty || w == null || w <= 0) {
                setState(() => error = 'Describe the cargo and enter its weight');
                return;
              }
              Navigator.pop(context, FreightDetails(cargo: cargo.text.trim(), weightKg: w, helpers: helpers));
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}


/// Groceries: saman ki list aur andazan budget.
Future<GroceryDetails?> editGrocery(BuildContext context, GroceryDetails? current) {
  return showModalBottomSheet<GroceryDetails>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GroceryForm(current: current),
  );
}

class _GroceryForm extends StatefulWidget {
  final GroceryDetails? current;
  const _GroceryForm({this.current});

  @override
  State<_GroceryForm> createState() => _GroceryFormState();
}

class _GroceryFormState extends State<_GroceryForm> {
  late final items = TextEditingController(text: widget.current?.items.join('\n'));
  late final budget = TextEditingController(text: widget.current?.budget.toString());
  late final note = TextEditingController(text: widget.current?.note);
  String? error;

  @override
  void dispose() {
    items.dispose();
    budget.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Shopping list', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('The driver buys these items at the store and brings them to you.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: items,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Items (one per line)',
              hintText: 'Milk 2 L\nBread\nEggs 1 dozen',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: budget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated cost of items',
              prefixText: 'Rs  ',
              helperText: 'You pay the actual item cost to the driver on delivery, plus the fare',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'Note for the shopper (optional)', hintText: 'Call me if something is out of stock'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final list = items.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final b = int.tryParse(budget.text.trim());
              if (list.isEmpty || b == null || b <= 0) {
                setState(() => error = 'Add at least one item and the estimated cost');
                return;
              }
              if (b > 20000) {
                setState(() => error = 'For orders above Rs 20,000 please split into smaller orders');
                return;
              }
              Navigator.pop(context, GroceryDetails(items: list, budget: b, note: note.text.trim()));
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }
}
