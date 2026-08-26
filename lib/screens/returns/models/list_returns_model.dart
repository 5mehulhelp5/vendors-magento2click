import 'package:flutter/foundation.dart';

import '../../../models/index.dart';
import '../../../services/index.dart';

/// Loads and holds the signed-in customer's returns for the My Returns list.
///
/// The returns list endpoint returns everything in one response, so this is a
/// simple single-shot loader (not the paged repository stack) — which also lets
/// the screen show a returns-specific empty state and a Start-a-return CTA.
class ListReturnsModel extends ChangeNotifier {
  ListReturnsModel({required this.user});

  final User user;
  final _services = Services();

  bool _loading = false;
  bool _loaded = false;
  List<ReturnRequest> _returns = <ReturnRequest>[];

  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  List<ReturnRequest> get returns => _returns;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final res = await _services.api.getMyReturns(user: user);
    _returns = res?.data ?? <ReturnRequest>[];
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() => load();
}
