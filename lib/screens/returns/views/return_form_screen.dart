import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/constants.dart';
import '../../../generated/l10n.dart';
import '../../../models/index.dart';
import '../models/create_return_model.dart';
import '../models/return_detail_model.dart';

/// Step 2 of "Start a return": for the chosen order, pick items + quantities +
/// a reason each, choose a resolution, add an optional comment, and submit.
class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({super.key, required this.order});

  final ReturnableOrder order;

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final _selected = <int, bool>{};
  final _qty = <int, int>{};
  final _reason = <int, String?>{};
  String? _resolution;
  final _comment = TextEditingController();

  CreateReturnModel get model =>
      Provider.of<CreateReturnModel>(context, listen: false);

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      final id = item.orderItemId;
      if (id != null) _qty[id] = 1;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted || msg.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _errText(Object e) {
    final s = e.toString();
    const prefix = 'Exception: ';
    return s.startsWith(prefix) ? s.substring(prefix.length) : s;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final lines = <ReturnLineInput>[];
    for (final item in widget.order.items) {
      final id = item.orderItemId;
      if (id == null || _selected[id] != true) continue;
      final reason = _reason[id];
      if (reason == null || reason.isEmpty) {
        _snack(S.of(context).selectReason);
        return;
      }
      lines.add(ReturnLineInput(
          orderItemId: id, qty: _qty[id] ?? 1, reason: reason));
    }
    if (lines.isEmpty) {
      _snack(S.of(context).selectItemsToReturn);
      return;
    }
    if (_resolution == null) {
      _snack(S.of(context).howToResolve);
      return;
    }
    final orderId = widget.order.orderId;
    if (orderId == null) {
      _snack(S.current.somethingWrong);
      return;
    }
    final comment = _comment.text.trim();
    try {
      final rma = await model.submit(
        orderId: orderId,
        items: lines,
        resolution: _resolution!,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      _snack(S.of(context).returnSubmitted);
      final id = rma.entityId;
      if (id != null) {
        Navigator.of(context).pushReplacementNamed(
          RouteList.returnDetail,
          arguments: ReturnDetailArguments(
            model: ReturnDetailModel(returnId: id, summary: rma),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack(_errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = context.watch<CreateReturnModel>().isSubmitting;
    final reasons = model.policy?.reasons ?? const <ReturnOption>[];
    final resolutions = model.policy?.resolutions ?? const <ReturnOption>[];

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        centerTitle: true,
        title: Text(
          S.of(context).startReturn,
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_sharp,
              color: theme.colorScheme.secondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              S.of(context).selectItemsToReturn,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final item in widget.order.items) _itemTile(context, item, reasons),
          const SizedBox(height: 8),
          _resolutionSelector(context, resolutions),
          _commentField(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(S.of(context).submitReturn),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(
      BuildContext context, ReturnableItem item, List<ReturnOption> reasons) {
    final theme = Theme.of(context);
    final id = item.orderItemId;
    if (id == null) return const SizedBox.shrink();
    final selected = _selected[id] ?? false;
    final maxQty = item.returnableQty.toInt();

    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: (v) => setState(() => _selected[id] = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(item.name ?? item.sku ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${S.of(context).qty}: $maxQty'),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  if (maxQty > 1) _qtyStepper(context, id, maxQty),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _reason[id],
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: S.of(context).selectReason,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final r in reasons)
                        DropdownMenuItem(
                          value: r.code,
                          child: Text(r.label ?? r.code ?? ''),
                        ),
                    ],
                    onChanged: (v) => setState(() => _reason[id] = v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _qtyStepper(BuildContext context, int id, int maxQty) {
    final qty = _qty[id] ?? 1;
    return Row(
      children: [
        Text(S.of(context).qty),
        const Spacer(),
        IconButton(
          onPressed: qty > 1 ? () => setState(() => _qty[id] = qty - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed:
              qty < maxQty ? () => setState(() => _qty[id] = qty + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _resolutionSelector(
      BuildContext context, List<ReturnOption> resolutions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DropdownButtonFormField<String>(
        value: _resolution,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: S.of(context).howToResolve,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final r in resolutions)
            DropdownMenuItem(
              value: r.code,
              child: Text(r.label ?? r.code ?? ''),
            ),
        ],
        onChanged: (v) => setState(() => _resolution = v),
      ),
    );
  }

  Widget _commentField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _comment,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: S.of(context).optionalComment,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
