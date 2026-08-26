import 'cart_base.dart';
import 'cart_model_magento.dart';

export 'cart_base.dart';

class CartInject {
  static final CartInject _instance = CartInject._internal();

  factory CartInject() => _instance;

  CartInject._internal();

  /// init default CartModel
  CartModel model = CartModelMagento();

  void init(config) {
    switch (config['type']) {
      case 'magento':
        model = CartModelMagento();
        break;
      default:
        model = CartModelMagento();
    }
    model.initData();
  }
}
