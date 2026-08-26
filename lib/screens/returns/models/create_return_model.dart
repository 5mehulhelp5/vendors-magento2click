import 'package:flutter/foundation.dart';

import '../../../generated/l10n.dart';
import '../../../models/index.dart';
import '../../../services/index.dart';

/// Drives the "Start a return" flow: loads the policy (which gates the whole
/// feature) and the returnable orders, and submits the chosen lines.
class CreateReturnModel extends ChangeNotifier {
  final _services = Services();

  bool _loading = false;
  bool _submitting = false;
  ReturnPolicy? _policy;
  List<ReturnableOrder> _orders = <ReturnableOrder>[];

  bool get isLoading => _loading;
  bool get isSubmitting => _submitting;
  ReturnPolicy? get policy => _policy;
  List<ReturnableOrder> get orders => _orders;
  bool get enabled => _policy?.enabled == true;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    // Fire both together: the policy gates the feature and supplies the option
    // lists, the orders populate the picker.
    final policyFuture = _services.api.getReturnPolicy();
    final ordersFuture = _services.api.getReturnableOrders();
    _policy = await policyFuture;
    _orders = await ordersFuture;
    _loading = false;
    notifyListeners();
  }

  /// Opens a return for [orderId]. Returns the created return; throws (with the
  /// server's shopper-ready message) on failure.
  Future<ReturnRequest> submit({
    required int orderId,
    required List<ReturnLineInput> items,
    required String resolution,
    String? comment,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final rma = await _services.api.createReturn(
        orderId: orderId,
        items: items,
        resolution: resolution,
        comment: comment,
      );
      if (rma == null) throw Exception(S.current.somethingWrong);
      return rma;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
