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
                    ? 'MIK DRIVE commission is taken from this balance after each ride.'
                    : 'Pay for rides with your wallet instead of cash.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: AppColors.dark),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                    icon: const Icon(Icons.add),
                    label: const Text('Top up'),
                  ),
                ),
                if (isDriver) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawScreen())),
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('Withdraw'),
                    ),
                  ),
                ],
              ]),
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
      TxStatus.pending => AppColors.warning,
      TxStatus.success => AppColors.brand,
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
            TxType.promo => Icons.local_offer_outlined,
            TxType.referral => Icons.card_giftcard,
            TxType.bonus => Icons.emoji_events_outlined,
            TxType.withdrawal => Icons.account_balance_outlined,
            TxType.refund => Icons.undo,
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
                    : AppColors.dark)),
        if (t.status != TxStatus.success)
          StatusChip(t.status == TxStatus.pending ? 'Pending' : 'Failed', statusColor),
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
              child: const Text('Send the amount to:\nMIK DRIVE (Pvt) Ltd · Meezan Bank\nIBAN PK00 MEZN 0000 0000 0000 0000\n'
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
          ? (Icons.schedule, AppColors.warning, 'Request submitted',
              'We will add ${pkr(t.amount)} to your wallet after checking your transfer.')
          : (Icons.hourglass_top, AppColors.warning, 'Processing payment…',
              'Confirm the payment in your ${t.method} app.'),
      TxStatus.success => (Icons.check_circle, AppColors.brand, 'Top-up successful',
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


/// Driver apni kamai JazzCash / Easypaisa / bank mein nikalta hai. Finance team approve karti hai.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final amount = TextEditingController();
  final account = TextEditingController();
  String method = 'JazzCash';
  String? error;
  bool done = false;

  @override
  void dispose() {
    amount.dispose();
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final balance = store.currentUser!.walletBalance;
    if (done) {
      return Scaffold(
        appBar: AppBar(title: const Text('Withdraw')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.schedule, size: 72, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('Request sent',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Our finance team usually sends the money within 24 hours.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to wallet')),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Available: ${pkr(balance)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs  ', helperText: 'Minimum Rs 500'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'Send to'),
            items: [
              for (final m in ['JazzCash', 'Easypaisa', 'Bank account']) DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => method = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: account,
            decoration: InputDecoration(labelText: method == 'Bank account' ? 'IBAN' : '$method number'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final a = int.tryParse(amount.text.trim());
              final acc = account.text.trim();
              if (a == null || acc.length < 4) {
                setState(() => error = 'Enter an amount and your account details');
                return;
              }
              final err = store.requestWithdrawal(a, method, '••••${acc.substring(acc.length - 4)}');
              setState(() {
                error = err;
                done = err == null;
              });
            },
            child: const Text('Request withdrawal'),
          ),
        ],
      ),
    );
  }
}
