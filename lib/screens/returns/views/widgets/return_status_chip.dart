import 'package:flutter/material.dart';

/// A small coloured pill showing a return's status. The colour is derived from
/// the machine [status]; the visible text is the server-provided [label] (which
/// is already localized), falling back to the raw status.
class ReturnStatusChip extends StatelessWidget {
  const ReturnStatusChip({super.key, this.status, this.label});

  final String? status;
  final String? label;

  Color _color() {
    switch ((status ?? '').toLowerCase()) {
      case 'pending':
      case 'awaiting_customer':
        return const Color(0xFFCE7A12); // amber
      case 'approved':
      case 'authorized':
        return const Color(0xFF0E7C86); // teal
      case 'shipped':
      case 'in_transit':
        return const Color(0xFF3B5BDB); // indigo
      case 'received':
      case 'processing':
        return const Color(0xFF6741D9); // violet
      case 'refunded':
      case 'completed':
      case 'closed':
      case 'resolved':
        return const Color(0xFF2B8A3E); // green
      case 'canceled':
      case 'cancelled':
      case 'rejected':
      case 'declined':
        return const Color(0xFFC92A2A); // red
      default:
        return const Color(0xFF868E96); // grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final text = (label != null && label!.isNotEmpty)
        ? label!
        : (status ?? '').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
