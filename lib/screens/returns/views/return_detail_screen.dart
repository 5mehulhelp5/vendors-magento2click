import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../common/tools.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart';
import '../../base_screen.dart';
import '../models/return_detail_model.dart';
import 'widgets/return_status_chip.dart';

/// The full detail of one return: items, tracking, message timeline, and the
/// write-actions. Action buttons are rendered from the server flags
/// ([ReturnRequest.canCancel] / [canAddTracking] / [needsCustomerReply]) — never
/// guessed from status.
class ReturnDetailScreen extends StatefulWidget {
  const ReturnDetailScreen({super.key});

  @override
  BaseScreen<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends BaseScreen<ReturnDetailScreen> {
  ReturnDetailModel get model =>
      Provider.of<ReturnDetailModel>(context, listen: false);

  final _commentController = TextEditingController();

  @override
  void afterFirstLayout(BuildContext context) {
    super.afterFirstLayout(context);
    model.load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted || msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _money(num? value, String? currencyCode) => value == null
      ? ''
      : PriceTools.getCurrencyFormatted(value, null, currency: currencyCode) ??
          '';

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final msg = await model.addComment(text);
      _commentController.clear();
      _snack(msg);
    } catch (e) {
      _snack(_errText(e));
    }
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(S.of(context).cancelReturnConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(context).no)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.of(context).yes)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _snack(await model.cancel());
    } catch (e) {
      _snack(_errText(e));
    }
  }

  Future<void> _addTracking(ReturnRequest r) async {
    final carriers = r.carriers;
    String? carrierCode = carriers.isNotEmpty ? carriers.first.code : null;
    final trackController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(S.of(context).addTracking,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: carrierCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: S.of(context).carrier,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in carriers)
                      DropdownMenuItem(
                        value: c.code,
                        child: Text(c.label ?? c.code ?? ''),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => carrierCode = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackController,
                  decoration: InputDecoration(
                    labelText: S.of(context).trackingNumber,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(S.of(context).submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final code = carrierCode;
    final number = trackController.text.trim();
    if (code == null || code.isEmpty || number.isEmpty) return;
    try {
      _snack(await model.addTracking(carrierCode: code, trackNumber: number));
    } catch (e) {
      _snack(_errText(e));
    }
  }

  static String _errText(Object e) {
    final s = e.toString();
    const prefix = 'Exception: ';
    return s.startsWith(prefix) ? s.substring(prefix.length) : s;
  }

  bool _canMessage(ReturnRequest r) {
    const closed = [
      'canceled',
      'cancelled',
      'refunded',
      'completed',
      'closed',
      'rejected',
      'resolved'
    ];
    return !closed.contains((r.status ?? '').toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        centerTitle: true,
        title: Text(
          S.of(context).returnDetails,
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_sharp,
              color: theme.colorScheme.secondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<ReturnDetailModel>(
        builder: (context, model, _) {
          final r = model.returnRequest;
          if (r == null) {
            if (model.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  model.error ?? S.of(context).returnsNotAvailable,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final currencyCode = Provider.of<AppModel>(context).currencyCode;
          return Column(
            children: [
              if (model.actionInProgress)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: model.load,
                  child: ListView(
                    // Needed so a short return (one item, no tracks/timeline)
                    // still overscrolls far enough to trigger the indicator.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      _header(context, r),
                      if (r.needsCustomerReply) _replyBanner(context),
                      _itemsCard(context, r, currencyCode),
                      _summaryCard(context, r, currencyCode),
                      if (r.tracks.isNotEmpty) _tracksCard(context, r),
                      if (r.timeline.isNotEmpty) _timelineCard(context, r),
                      _actionButtons(context, r),
                    ],
                  ),
                ),
              ),
              if (_canMessage(r)) _commentBar(context, r),
            ],
          );
        },
      ),
    );
  }

  // --- Sections -------------------------------------------------------------

  Widget _card(BuildContext context,
      {required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ReturnRequest r) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.incrementId ?? '#${r.entityId ?? ''}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              ReturnStatusChip(status: r.status, label: r.statusLabel),
            ],
          ),
          const SizedBox(height: 10),
          if (r.orderIncrementId != null)
            _infoRow(context, S.of(context).orderId, r.orderIncrementId!),
          if (r.createdAt != null)
            _infoRow(context, S.of(context).orderDate,
                DateFormat('d MMM yyyy, HH:mm').format(r.createdAt!)),
        ],
      ),
    );
  }

  Widget _replyBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFCE7A12).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCE7A12).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline,
              color: Color(0xFFCE7A12), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context).awaitingYourReply,
              style: const TextStyle(
                  color: Color(0xFF9A5A0E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(
      BuildContext context, ReturnRequest r, String? currencyCode) {
    final theme = Theme.of(context);
    return _card(
      context,
      title: S.of(context).returnedItems,
      child: Column(
        children: [
          for (final item in r.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name ?? item.sku ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (item.reasonLabel != null)
                              '${S.of(context).returnReason}: ${item.reasonLabel}',
                            '${S.of(context).qty}: ${_qtyText(item)}',
                          ].join('   ·   '),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.rowTotal != null || item.price != null)
                    Text(
                      _money(item.rowTotal ?? item.price, currencyCode),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _qtyText(ReturnItem item) {
    final requested = item.qtyRequested;
    final received = item.qtyReceived;
    if (received != null && received > 0 && received != requested) {
      return '$received / ${requested ?? ''}';
    }
    return '${requested ?? ''}';
  }

  Widget _summaryCard(
      BuildContext context, ReturnRequest r, String? currencyCode) {
    return _card(
      context,
      title: S.of(context).returnDetails,
      child: Column(
        children: [
          if (r.resolutionLabel != null)
            _infoRow(context, S.of(context).resolution, r.resolutionLabel!),
          if (r.refundAmount != null)
            _infoRow(context, S.of(context).refundAmount,
                _money(r.refundAmount, currencyCode)),
          if (r.customerComment != null && r.customerComment!.isNotEmpty)
            _infoRow(context, S.of(context).comment, r.customerComment!),
          if (r.returnAddress != null && r.returnAddress!.isNotEmpty)
            _infoRow(context, S.of(context).returnAddress, r.returnAddress!),
        ],
      ),
    );
  }

  Widget _tracksCard(BuildContext context, ReturnRequest r) {
    return _card(
      context,
      title: S.of(context).trackingNumber,
      child: Column(
        children: [
          for (final t in r.tracks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        t.carrierTitle ?? t.carrierCode ?? '',
                        t.trackNumber ?? ''
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineCard(BuildContext context, ReturnRequest r) {
    final theme = Theme.of(context);
    return _card(
      context,
      title: S.of(context).returnHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in r.timeline)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.statusLabel != null)
                          Text(e.statusLabel!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        if (e.comment != null && e.comment!.isNotEmpty)
                          Text(e.comment!,
                              style: const TextStyle(fontSize: 13)),
                        if (e.createdAt != null)
                          Text(
                            DateFormat('d MMM yyyy, HH:mm')
                                .format(e.createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  theme.colorScheme.secondary.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButtons(BuildContext context, ReturnRequest r) {
    final buttons = <Widget>[
      if (r.canAddTracking)
        OutlinedButton.icon(
          onPressed: model.actionInProgress ? null : () => _addTracking(r),
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: Text(S.of(context).addTracking),
        ),
      if (r.canCancel)
        OutlinedButton.icon(
          onPressed: model.actionInProgress ? null : _confirmCancel,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: Text(S.of(context).cancelReturn),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Wrap(spacing: 10, runSpacing: 10, children: buttons),
    );
  }

  Widget _commentBar(BuildContext context, ReturnRequest r) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
              top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: r.needsCustomerReply
                      ? S.of(context).reply
                      : S.of(context).optionalComment,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            IconButton(
              onPressed: model.actionInProgress ? null : _sendComment,
              icon: Icon(Icons.send, color: theme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.secondary.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
