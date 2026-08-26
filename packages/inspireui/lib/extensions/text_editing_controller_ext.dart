import 'package:flutter/widgets.dart';

extension TextEditingControllerExt on TextEditingController {
  /// Select all the [text]
  void selectAll() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }
}
