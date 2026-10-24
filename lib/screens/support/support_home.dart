import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../chat_screen.dart';

const _faq = [
  ('How is the fare decided?',
      'You offer your own fare. Drivers nearby can accept it or send a counter-offer, and you choose the driver you like.'),
  ('How do I pay?', 'Pay the driver in cash at the end of the ride. The agreed fare is shown in the app.'),
  ('I left something in the car',
      'Open "My rides", find the trip, then create a support ticket with category "Lost item". We will contact the driver.'),
  ('How do I become a driver?',
      'Open the menu, tap "Driver mode" and complete the registration with your CNIC, license and vehicle documents. Our team reviews it within 24 hours.'),
  ('How does commission work for drivers?',
      'MIK DRIVE keeps a small percentage of each completed ride. You can see it on the Driver mode earnings card.'),
  ('How do I cancel a ride?',
      'Tap "Cancel ride" before the trip starts and choose a reason. Frequent cancellations may lower your rating.'),
];

class SupportHome extends StatelessWidget {
  const SupportHome({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tickets = store.myTickets;
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.dark,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTicketScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const Text('My requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('You have no support requests', style: TextStyle(color: AppColors.muted)),
            ),
          for (final t in tickets)
            Card(
              elevation: 0,
              color: AppColors.surface,
              child: ListTile(
                title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t.messages.last.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: StatusChip(t.status.label, ticketColor(t.status)),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => TicketThreadScreen(ticket: t))),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Frequently asked questions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          for (final (q, a) in _faq)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(q),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(a, style: const TextStyle(color: AppColors.muted))],
            ),
        ],
      ),
    );
  }
}

Color ticketColor(TicketStatus s) => switch (s) {
      TicketStatus.open => Colors.orange.shade800,
      TicketStatus.answered => Colors.blue.shade700,
      TicketStatus.closed => AppColors.muted,
    };

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  String? category;
  String? rideId;
  final msg = TextEditingController();
  String? error;

  @override
  void dispose() {
    msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final myRides = store.historyFor(store.currentUser!.id).take(10).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'What do you need help with?'),
            items: [for (final c in supportCategories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => category = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: rideId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Related ride (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No specific ride')),
              for (final r in myRides)
                DropdownMenuItem(
                  value: r.id,
                  child: Text('${r.from.name} → ${r.to.name} · ${pkr(r.finalFare)}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => rideId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: msg,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Describe the problem'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (category == null || msg.text.trim().length < 5) {
                setState(() => error = 'Choose a category and describe the problem');
                return;
              }
              final t = store.createTicket(category: category!, rideId: rideId, message: msg.text.trim());
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => TicketThreadScreen(ticket: t)));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class TicketThreadScreen extends StatefulWidget {
  final SupportTicket ticket;
  const TicketThreadScreen({super.key, required this.ticket});

  @override
  State<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends State<TicketThreadScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.category, style: const TextStyle(fontSize: 17)),
          Text('Ticket ${t.id} · ${t.status.label}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in t.messages)
                ChatBubble(
                  text: m.text,
                  mine: !m.fromSupport,
                  time: m.time,
                  label: m.fromSupport ? 'MIK DRIVE Support' : null,
                ),
            ],
          ),
        ),
        if (t.status == TicketStatus.closed)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('This request is closed. Create a new request if you need more help.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          )
        else
          MessageInput(
            controller: ctrl,
            hint: 'Write a reply',
            onSend: (text) {
              if (text.trim().isEmpty) return;
              store.userReplyTicket(t, text.trim());
              ctrl.clear();
            },
          ),
      ]),
    );
  }
}
