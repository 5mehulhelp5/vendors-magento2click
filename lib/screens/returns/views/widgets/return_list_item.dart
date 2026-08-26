import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/constants.dart';
import '../../../../generated/l10n.dart';
import '../../../../models/index.dart';
import '../../models/return_detail_model.dart';
import 'return_status_chip.dart';

/// One row on the My Returns list — a summary card that opens the full detail.
class ReturnListItem extends StatelessWidget {
  const ReturnListItem({super.key, required this.returnRequest});

  final ReturnRequest returnRequest;

  void _openDetail(BuildContext context) {
    final id = returnRequest.entityId;
    if (id == null) return;
    Navigator.of(context).pushNamed(
      RouteList.returnDetail,
      arguments: ReturnDetailArguments(
        model: ReturnDetailModel(returnId: id, summary: returnRequest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = returnRequest;
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.incrementId ?? '#${r.entityId ?? ''}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReturnStatusChip(status: r.status, label: r.statusLabel),
                ],
              ),
              const SizedBox(height: 10),
              if (r.orderIncrementId != null)
                _line(context, Icons.receipt_long_outlined,
                    '${S.of(context).orderId}: ${r.orderIncrementId}'),
              if (r.createdAt != null)
                _line(context, Icons.schedule,
                    DateFormat('d MMM yyyy, HH:mm').format(r.createdAt!)),
              _line(context, Icons.inventory_2_outlined,
                  '${S.of(context).items}: ${r.displayItemCount}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    final color = Theme.of(context).colorScheme.secondary.withOpacity(0.7);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
