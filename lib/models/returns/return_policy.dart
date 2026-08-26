import 'package:inspireui/inspireui.dart';

import 'return_parse.dart';

/// A selectable `{code, label}` option from the return policy — reused for
/// reasons, resolutions, conditions and carriers. Show [label], submit [code].
class ReturnOption {
  String? code;
  String? label;

  ReturnOption.fromJson(Map json) {
    code = json['code']?.toString();
    label = json['label']?.toString();
  }
}

/// Store-wide returns configuration. Fetch this first and drive the whole
/// returns UI from it: [enabled] gates the entire feature, [trackingEnabled]
/// gates every tracking affordance, and the option lists populate the create
/// form. Show each option's `label`, submit its `code`.
class ReturnPolicy {
  bool enabled = false;
  bool trackingEnabled = false;
  int? returnWindowDays;
  String? policyPage;
  List<ReturnOption> reasons = [];
  List<ReturnOption> resolutions = [];
  List<ReturnOption> conditions = [];
  List<ReturnOption> carriers = [];

  ReturnPolicy.fromJson(Map json) {
    try {
      enabled = json['enabled'] == true;
      trackingEnabled = json['tracking_enabled'] == true;
      returnWindowDays = parseReturnInt(json['return_window_days']);
      policyPage = json['policy_page']?.toString();
      reasons = parseReturnList(json['reasons'], ReturnOption.fromJson);
      resolutions = parseReturnList(json['resolutions'], ReturnOption.fromJson);
      conditions = parseReturnList(json['conditions'], ReturnOption.fromJson);
      carriers = parseReturnList(json['carriers'], ReturnOption.fromJson);
    } catch (e) {
      printLog('ReturnPolicy.fromJson $e');
    }
  }
}
