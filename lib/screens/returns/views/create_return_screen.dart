import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n.dart';
import '../../../models/index.dart';
import '../models/create_return_model.dart';
import 'return_form_screen.dart';

/// Step 1 of "Start a return": gate on the policy, then let the customer pick
/// which returnable order to open a return against.
class CreateReturnScreen extends StatefulWidget {
  const CreateReturnScreen({super.key});

  @override
  State<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  CreateReturnModel get model =>
      Provider.of<CreateReturnModel>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) model.load();
    });
  }

  void _openForm(ReturnableOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<CreateReturnModel>.value(
          value: model,
          child: ReturnFormScreen(order: order),
        ),
      ),
    );
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
          S.of(context).startReturn,
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_sharp,
              color: theme.colorScheme.secondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<CreateReturnModel>(
        builder: (context, model, _) {
          if (model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!model.enabled) {
            return _message(
                context, S.of(context).returnsNotAvailable, Icons.info_outline);
          }
          if (model.orders.isEmpty) {
            return _message(context, S.of(context).noItemsEligibleForReturn,
                Icons.inventory_2_outlined);
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  S.of(context).selectItemsToReturn,
                  style: TextStyle(
                      color: theme.colorScheme.secondary.withOpacity(0.7)),
                ),
              ),
              for (final order in model.orders) _orderCard(context, order),
            ],
          );
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, ReturnableOrder order) {
    final theme = Theme.of(context);
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
        onTap: () => _openForm(order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${S.of(context).orderId}: ${order.orderIncrementId ?? order.orderId ?? ''}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (order.createdAt != null)
                      Text(
                        DateFormat('d MMM yyyy').format(order.createdAt!),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                theme.colorScheme.secondary.withOpacity(0.7)),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${S.of(context).items}: ${order.items.length}',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.secondary.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.secondary.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: theme.colorScheme.secondary.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.secondary.withOpacity(0.7),
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
