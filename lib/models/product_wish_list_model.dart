import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart';
import '../app.dart';
import '../common/tools/flash.dart';
import '../data/boxes.dart';
import '../generated/l10n.dart';
import '../services/index.dart';
import 'entities/product.dart';

class ProductWishListModel extends ChangeNotifier {
  ProductWishListModel() {
    getLocalWishlist();
  }

  List<Product> products = [];

  bool _isFetching = false;

  List<Product> getWishList() => products;

  int get wishlistCount => products.length;

  Future<void> addToWishlist(Product product) async {
    if (!UserBox().isLoggedIn) {
      _failMessage(S.current.mustLoginToWishlist);
      return;
    }
    final isExist = products.indexWhere((item) => item.id == product.id) != -1;
    if (!isExist) {

      final message =  await Services().api.addProductToWishList(product);
      if((message ?? "").isEmpty) {
        products.add(product);
        saveWishlist(products);
        notifyListeners();
      }else{
        _failMessage(message!);
      }
    }
  }

  Future<void> removeToWishlist(Product product) async {
    final index = products.indexWhere((item) => item.id == product.id);
    if (index != -1) {
      // The wishlist *item* id is what the remove endpoint takes, and only the
      // wishlist feed carries it — a product opened from a listing or a search
      // result has none, so the heart button on the product page removed
      // nothing server-side. Take the id from our own copy of the entry.
      final itemID = product.itemID ?? products[index].itemID ?? '';
      products = products.where((item) => item.id != product.id).toList();
      final message = await Services().api.removeProductToWishList(itemID);
      if((message ?? "").isEmpty){
        saveWishlist(products);
        notifyListeners();
      }else{
        _failMessage(message!);
      }
    }
  }

  Future<void> saveWishlist(List<Product> products) async {
    try {
      UserBox().wishList = products;
    } catch (err, trace) {
      printError(err, trace, '[ProductWishListModel] saveWishlist error');
    }
  }

  /// Pull the wishlist from the server. Safe to call on every wishlist open:
  /// the current list is replaced only after a successful fetch.
  ///
  /// It used to clear first, which also wiped the saved copy — so a failed
  /// request (a flaky network, or the backend 401 that the integration token
  /// currently gets) emptied the wishlist and nothing refilled it until the
  /// next login.
  ///
  /// A fetch that is already running wins: opening the wishlist tab triggers
  /// this from both the tab tap and the screen becoming visible, and that
  /// should still be one request.
  Future<void> getLocalWishlist() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      // Nothing to fetch for a signed-out customer, and whatever is in memory
      // belongs to whoever was signed in before — drop it.
      if (!UserBox().isLoggedIn) {
        await clearWishList();
        return;
      }
      final wishList = await Services().api.getWishList();//UserBox().wishList;
      if (wishList != null) {
        products = wishList;
        await saveWishlist(products);
        notifyListeners();
      }
    } catch (err, trace) {
      printError(err, trace, '[ProductWishListModel] getLocalWishlist error');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> clearWishList() async {
    products = [];
    await saveWishlist(products);
    notifyListeners();
  }

  void _failMessage(String message) {

    if (message.isEmpty) return;
    FlashHelper.errorMessage(
      App.fluxStoreNavigatorKey.currentContext!,
      message: message,
    );
  }
}
