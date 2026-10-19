import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Ride ke dauran passenger aur driver ki chat.
class RideChatScreen extends StatefulWidget {
  final RideRequest ride;
  const RideChatScreen({super.key, required this.ride});

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final ctrl = TextEditingController();

  static const quickReplies = ['I am waiting outside', 'Where are you?', 'Coming in 2 minutes', 'OK'];

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    StoreScope.of(context).sendChat(widget.ride, text.trim());
    ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.currentUser!.id;
    final ride = widget.ride;
    final otherId = me == ride.passengerId ? ride.driverId! : ride.passengerId;
    final other = store.userById(otherId);
    return Scaffold(
      appBar: AppBar(title: Text(other.name)),
      body: Column(children: [
        Expanded(
          child: ride.chat.isEmpty
              ? const Center(
                  child: Text('Send a message to coordinate pickup',
                      style: TextStyle(color: AppColors.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final m in ride.chat) ChatBubble(text: m.text, mine: m.senderId == me, time: m.time),
                  ],
                ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final q in quickReplies)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(label: Text(q), onPressed: () => _send(q)),
                ),
            ],
          ),
        ),
        MessageInput(controller: ctrl, onSend: _send),
      ]),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final DateTime time;
  final String? label;
  const ChatBubble({super.key, required this.text, required this.mine, required this.time, this.label});

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.brand : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (label != null)
              Text(label!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Text(text),
            const SizedBox(height: 2),
            Text(hhmm(time), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ]),
        ),
      );
}

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final String hint;
  const MessageInput({super.key, required this.controller, required this.onSend, this.hint = 'Message'});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: onSend,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.dark),
              onPressed: () => onSend(controller.text),
              icon: const Icon(Icons.send, color: AppColors.brand),
            ),
          ]),
        ),
      );
}
