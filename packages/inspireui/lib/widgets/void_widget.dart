import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A [VoidWidget] instance, you can use in your layouts.
const kVoidWidget = VoidWidget();

/// A widget which is not in the layout and does nothing.
/// It is useful when you have to return a widget and can't return null.
class VoidWidget extends Widget {
  /// Creates a [VoidWidget] widget.
  const VoidWidget({Key? key}) : super(key: key);

  @override
  Element createElement() => _VoidWidgetElement(this);
}

class _VoidWidgetElement extends Element {
  _VoidWidgetElement(VoidWidget widget) : super(widget);

  @override
  void mount(Element? parent, dynamic newSlot) {
    if (kDebugMode) {
      assert(parent is! MultiChildRenderObjectElement, """
        You are using VoidWidget under a MultiChildRenderObjectElement.
        This suggests a possibility that the VoidWidget is not needed or is being used improperly.
        Make sure it can't be replaced with an inline conditional or
        omission of the target widget from a list.
        """);
    }

    super.mount(parent, newSlot);
  }

  @override
  bool get debugDoingBuild => false;

  @override
  void performRebuild() {
    super.performRebuild();
  }
}
