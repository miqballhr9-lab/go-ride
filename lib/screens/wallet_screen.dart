import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final u = store.currentUser!;
    final txs = store.transactionsFor(u.id);
    final isDriver = store.mode == AppMode.driver;
    final low = isDriver && u.walletBalance < AppStore.minDriverBalance;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Balance', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 4),
              Text(pkr(u.walletBalance),
                  style: TextStyle(
                      color: u.walletBalance < 0 ? const Color(0xFFFF8A8A) : AppColors.brand,
                      fontSize: 34,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                isDriver
                    ? 'Go Ride commission is taken from this balance after each ride.'
                    : 'Pay for rides with your wallet instead of cash.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Top up'),
              ),
            ]),
          ),
          if (low) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Your balance is below zero. Top up to go online and receive requests.',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 20),
          const Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          if (txs.isEmpty)
            const Text('No transactions yet', style: TextStyle(color: AppColors.muted)),
          for (final t in txs) TransactionTile(t: t),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final WalletTransaction t;
  final String? who;
  const TransactionTile({super.key, required this.t, this.who});

  @override
  Widget build(BuildContext context) {
    final positive = t.amount >= 0;
    final statusColor = switch (t.status) {
      TxStatus.pending => Colors.orange.shade800,
      TxStatus.success => Colors.green.shade700,
      TxStatus.failed => AppColors.danger,
    };
    final detail = [
      ?who,
      if (t.method != null) t.method!,
      if (t.rideId != null) 'Ride ${t.rideId}',
      if (t.note.isNotEmpty) t.note,
      timeAgo(t.time),
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Icon(
          switch (t.type) {
            TxType.topUp => Icons.account_balance_wallet_outlined,
            TxType.commission => Icons.percent,
            TxType.ridePayment => Icons.directions_car_outlined,
            TxType.rideEarning => Icons.payments_outlined,
            TxType.adjustment => Icons.tune,
          },
          color: AppColors.dark,
        ),
      ),
      title: Text(t.type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${positive ? '+' : '−'}${pkr(t.amount.abs())}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: t.status == TxStatus.failed
                    ? AppColors.muted
                    : (positive ? Colors.green.shade700 : AppColors.dark))),
        if (t.status != TxStatus.success)
          Text(t.status == TxStatus.pending ? 'Pending' : 'Failed',
              style: TextStyle(fontSize: 12, color: statusColor)),
      ]),
    );
  }
}

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final amount = TextEditingController(text: '1000');
  final account = TextEditingController();
  String method = topUpMethods.first;
  String? error;
  WalletTransaction? submitted;

  @override
  void dispose() {
    amount.dispose();
    account.dispose();
    super.dispose();
  }

  String get _accountLabel => switch (method) {
        'JazzCash' || 'Easypaisa' => '$method mobile number',
        'Debit / credit card' => 'Card number',
        _ => 'Bank transaction reference',
      };

  void _pay() {
    final a = int.tryParse(amount.text.trim());
    setState(() => error = null);
    if (a == null || a < 100 || a > 50000) {
      setState(() => error = 'Enter an amount between Rs 100 and Rs 50,000');
      return;
    }
    if (account.text.trim().length < 4) {
      setState(() => error = 'Enter your ${_accountLabel.toLowerCase()}');
      return;
    }
    final store = StoreScope.of(context);
    setState(() => submitted = store.topUp(a, method, account: _masked(account.text.trim())));
  }

  String _masked(String v) => method == 'Bank transfer' ? v : '••••${v.substring(v.length - 4)}';

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context); // status badalne pe rebuild
    final t = submitted;
    if (t != null) return _result(t);
    return Scaffold(
      appBar: AppBar(title: const Text('Top up')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(prefixText: 'Rs  ', labelText: 'Amount'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final v in [500, 1000, 2000, 5000])
              ActionChip(label: Text(pkr(v)), onPressed: () => setState(() => amount.text = '$v')),
          ]),
          const SizedBox(height: 20),
          const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioGroup<String>(
            groupValue: method,
            onChanged: (v) => setState(() => method = v!),
            child: Column(children: [
              for (final m in topUpMethods)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: m,
                  title: Text(m),
                  subtitle: Text(m == 'Bank transfer' ? 'Checked by our team, usually within 1 hour' : 'Instant'),
                ),
            ]),
          ),
          if (method == 'Bank transfer')
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: const Text('Send the amount to:\nGo Ride (Pvt) Ltd · Meezan Bank\nIBAN PK00 MEZN 0000 0000 0000 0000\n'
                  'Then enter your transaction reference below.'),
            ),
          TextField(controller: account, decoration: InputDecoration(labelText: _accountLabel)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _pay, child: Text(method == 'Bank transfer' ? 'Submit' : 'Pay ${pkr(int.tryParse(amount.text) ?? 0)}')),
          const SizedBox(height: 8),
          const Text('Demo: no real money is charged.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _result(WalletTransaction t) {
    final (icon, color, title, text) = switch (t.status) {
      TxStatus.pending => t.method == 'Bank transfer'
          ? (Icons.schedule, Colors.orange.shade800, 'Request submitted',
              'We will add ${pkr(t.amount)} to your wallet after checking your transfer.')
          : (Icons.hourglass_top, Colors.orange.shade800, 'Processing payment…',
              'Confirm the payment in your ${t.method} app.'),
      TxStatus.success => (Icons.check_circle, Colors.green.shade700, 'Top-up successful',
          '${pkr(t.amount)} has been added to your wallet.'),
      TxStatus.failed => (Icons.error, AppColors.danger, 'Top-up failed', 'Please try again.'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Top up')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(icon, size: 72, color: color),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to wallet')),
        ]),
      ),
    );
  }
}
