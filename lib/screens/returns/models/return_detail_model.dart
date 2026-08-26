import 'package:flutter/foundation.dart';

import '../../../models/index.dart';
import '../../../services/index.dart';

/// Route arguments for the return detail screen — carries the already-built
/// model so it can be re-provided with `ChangeNotifierProvider.value`.
class ReturnDetailArguments {
  ReturnDetailArguments({required this.model});
  final ReturnDetailModel model;
}

/// Holds one return in full and runs its write-actions (cancel / comment /
/// tracking). Every action re-fetches the detail afterward so the action flags
/// and timeline stay in sync — mirrors [OrderHistoryDetailModel].
class ReturnDetailModel extends ChangeNotifier {
  ReturnDetailModel({required this.returnId, ReturnRequest? summary})
      : _return = summary;

  final int returnId;
  final _services = Services();

  ReturnRequest? _return;
  bool _loading = false;
  bool _actionInProgress = false;
  String? _error;

  ReturnRequest? get returnRequest => _return;
  bool get isLoading => _loading;
  bool get actionInProgress => _actionInProgress;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final detail = await _services.api.getReturnDetail(returnId);
      if (detail != null) _return = detail;
    } catch (e) {
      _error = _messageOf(e);
    }
    _loading = false;
    notifyListeners();
  }

  /// Returns the server's confirmation message on success; throws (with the
  /// server's shopper-ready message) on failure so the screen can surface it.
  Future<String> cancel({String? comment}) =>
      _run(() => _services.api.cancelReturn(returnId, comment: comment));

  Future<String> addComment(String comment) =>
      _run(() => _services.api.addReturnComment(returnId, comment));

  Future<String> addTracking({
    required String carrierCode,
    required String trackNumber,
  }) =>
      _run(() => _services.api.addReturnTracking(
            returnId,
            carrierCode: carrierCode,
            trackNumber: trackNumber,
          ));

  Future<String> _run(Future<String> Function() action) async {
    _actionInProgress = true;
    notifyListeners();
    try {
      final message = await action();
      await _reload();
      return message;
    } finally {
      _actionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    try {
      final detail = await _services.api.getReturnDetail(returnId);
      if (detail != null) _return = detail;
    } catch (_) {
      // Keep the last good detail; the action result was already surfaced.
    }
  }

  static String _messageOf(Object e) {
    final s = e.toString();
    const prefix = 'Exception: ';
    return s.startsWith(prefix) ? s.substring(prefix.length) : s;
  }
}
