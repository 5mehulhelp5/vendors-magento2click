import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/constants.dart';
import '../../../generated/l10n.dart';
import '../../common/app_bar_mixin.dart';
import '../models/list_returns_model.dart';
import 'widgets/return_list_item.dart';

/// The My Returns list screen: the customer's returns, newest first, with a
/// Start-a-return CTA. Self-gates to a clean empty state when there are none.
class ListReturnsScreen extends StatefulWidget {
  const ListReturnsScreen({super.key});

  @override
  State<ListReturnsScreen> createState() => _ListReturnsScreenState();
}

class _ListReturnsScreenState extends State<ListReturnsScreen>
    with AppBarMixin {
  ListReturnsModel get model =>
      Provider.of<ListReturnsModel>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) model.load();
    });
  }

  Future<void> _startReturn() async {
    await Navigator.of(context).pushNamed(RouteList.returnCreate);
    // Coming back from the create flow — a new return may have been opened.
    if (mounted) model.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return renderScaffold(
      routeName: RouteList.returns,
      backgroundColor: theme.colorScheme.background,
      secondAppBar: AppBar(
        title: Text(
          S.of(context).myReturns,
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_sharp,
              color: theme.colorScheme.secondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startReturn,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(S.of(context).startReturn),
      ),
      child: Consumer<ListReturnsModel>(
        builder: (context, model, _) {
          if (model.isLoading && model.returns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: model.refresh,
            child: model.returns.isEmpty
                ? _emptyState(context)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 96),
                    itemCount: model.returns.length,
                    itemBuilder: (_, i) =>
                        ReturnListItem(returnRequest: model.returns[i]),
                  ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    // Wrapped in a scrollable so pull-to-refresh still works while empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_return_outlined,
                size: 72,
                color: theme.colorScheme.secondary.withOpacity(0.25),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  S.of(context).noReturnsYet,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.secondary.withOpacity(0.7),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
