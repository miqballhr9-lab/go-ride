import 'package:flutter/material.dart';

import 'common.dart';

/// Ride ke baad rating: sitare, tayyar tags aur apna comment.
class ReviewInput extends StatefulWidget {
  final String title;
  final List<String> tags;
  final void Function(int stars, String review) onSubmit;
  const ReviewInput({super.key, required this.title, required this.tags, required this.onSubmit});

  @override
  State<ReviewInput> createState() => _ReviewInputState();
}

class _ReviewInputState extends State<ReviewInput> {
  int stars = 5;
  final Set<String> selected = {};
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.title, textAlign: TextAlign.center),
      StarPicker(value: stars, onChanged: (v) => setState(() => stars = v)),
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final t in widget.tags)
          FilterChip(
            label: Text(t),
            selected: selected.contains(t),
            onSelected: (on) => setState(() => on ? selected.add(t) : selected.remove(t)),
          ),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: comment,
        decoration: const InputDecoration(hintText: 'Add a comment (optional)', isDense: true),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: () {
          final parts = [...selected, if (comment.text.trim().isNotEmpty) comment.text.trim()];
          widget.onSubmit(stars, parts.join(' · '));
        },
        child: const Text('Done'),
      ),
    ]);
  }
}
