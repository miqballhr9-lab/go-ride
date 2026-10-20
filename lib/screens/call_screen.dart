import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// App ke andar call (dono taraf ka asli number chhupa rehta hai).
/// Demo mein sirf screen hai; asli app mein yahan VoIP ya masked number lagega.
class CallScreen extends StatefulWidget {
  final RideRequest ride;
  const CallScreen({super.key, required this.ride});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _timer;
  int seconds = 0;
  bool connected = false;
  bool muted = false;
  bool speaker = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (!connected && seconds >= 2) {
          connected = true;
          seconds = 0;
        } else {
          seconds++;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _end() {
    StoreScope.of(context).logCall(widget.ride, connected ? seconds : 0);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.currentUser!.id;
    final r = widget.ride;
    final other = store.userById(me == r.passengerId ? r.driverId! : r.passengerId);
    final m = seconds ~/ 60, s = (seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Avatar(other.name, size: 110),
          const SizedBox(height: 20),
          Text(other.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(connected ? '$m:$s' : 'Calling…', style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('Your phone number is hidden', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _round(muted ? Icons.mic_off : Icons.mic, 'Mute', muted, () => setState(() => muted = !muted)),
            _round(Icons.volume_up, 'Speaker', speaker, () => setState(() => speaker = !speaker)),
          ]),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _end,
            child: const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.call_end, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 8),
          const Text('End call', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _round(IconData icon, String label, bool on, VoidCallback onTap) => Column(children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: on ? Colors.white : Colors.white12,
            child: Icon(icon, color: on ? AppColors.dark : Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ]);
}

/// Call aur Chat ke buttons, dono ride screens pe.
class ContactButtons extends StatelessWidget {
  final RideRequest ride;
  final VoidCallback openChat;
  const ContactButtons({super.key, required this.ride, required this.openChat});

  @override
  Widget build(BuildContext context) {
    final unread = ride.chat.where((m) => !m.isCall).length;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(ride: ride))),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Call'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: openChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(unread == 0 ? 'Message' : 'Message ($unread)'),
        ),
      ),
    ]);
  }
}
