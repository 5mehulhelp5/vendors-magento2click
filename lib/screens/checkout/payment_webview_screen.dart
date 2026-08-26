
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:inspireui/inspireui.dart' show printLog;

import '../../common/config.dart';
import '../../services/index.dart';
import '../../widgets/common/webview.dart';
import '../base_screen.dart';

class PaymentWebview extends StatefulWidget {
  final String? url;
  final Function? onFinish;
  final Function? onClose;
  final String paymentKey;
  final String paymentMethod;

  const PaymentWebview({this.onFinish, this.onClose, this.url, required this.paymentKey, required this.paymentMethod});

  // @override
  // State<StatefulWidget> createState() {
  //   return PaymentWebviewState();
  // }
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}


class _PaymentScreenState extends State<PaymentWebview> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (WebResourceError error) {
          // Don't tear the payment screen down for benign errors.
          //
          // This used to pop unconditionally and report "Payment failed" for
          // *any* error the webview raised, which is far too broad on iOS.
          //
          // Android populates isForMainFrame, so a failed subresource can be
          // ignored outright. iOS never sets it: webview_flutter_wkwebview
          // builds WebResourceError from an NSError and leaves isForMainFrame
          // null, so it must not be treated as "main frame" evidence there.
          //
          // WKWebView also reports *cancelled* navigations — NSURLErrorCancelled
          // (-999) — which happen routinely when one navigation supersedes
          // another during a 3-D Secure redirect chain. Those arrive with
          // errorType null, because only WKErrorDomain codes are mapped to a
          // type; -999 is NSURLErrorDomain. Matching on the raw code is the
          // only reliable signal, and it can't collide with Android, whose
          // error codes are small negatives (-1, -2, …).
          const nsUrlErrorCancelled = -999;
          if (error.isForMainFrame == false) return;
          if (error.errorCode == nsUrlErrorCancelled) return;
          if (!mounted) return;

          Navigator.of(context).pop();
          widget.onFinish?.call(false, 'WebView error: ${error.description}');
        },
        onUrlChange: (UrlChange change) {
          _handleUrlChange(change.url ?? '');
        },
      ))
      ..loadRequest(Uri.parse(_getPaymentUrl()));
  }

  String _getPaymentUrl() {
    switch (widget.paymentMethod.toLowerCase()) {
      case 'online':
        return 'https://accept.paymob.com/api/acceptance/iframes/${_getIframeId(widget.paymentMethod)}?payment_token=${widget.paymentKey}';
      case 'sympl':
        return 'https://accept.paymobsolutions.com/api/acceptance/iframes/${_getIframeId(widget.paymentMethod)}?payment_token=${widget.paymentKey}';
      case 'aman':
        return 'https://accept.paymobsolutions.com/api/acceptance/iframes/${_getIframeId(widget.paymentMethod)}?payment_token=${widget.paymentKey}';
      default:
        return 'https://accept.paymob.com/api/acceptance/iframes/your-frame-id?payment_token=${widget.paymentKey}';
    }
  }

  String _getIframeId(String paymentMethod) {
    // Replace with your actual iframe IDs from Paymob dashboard
    switch (paymentMethod.toLowerCase()) {
      case 'online':
        return '937826';
      case 'sympl':
        return '937825';
      case 'aman':
        return '937825';
      default:
        return '937826';
    }
  }

  void _handleUrlChange(String url) {
    // printLog, not print: this URL carries the Paymob payment_token and the
    // 3-D Secure redirect parameters, and print is not stripped in release.
    printLog('[Payment] url changed');
    if (url.contains('success') || url.contains('processed') || url.contains('confirmation')) {
      Navigator.of(context).pop();
      widget.onFinish?.call(true, 'Payment completed successfully');
    } else if (url.contains('fail') || url.contains('error')) {
      Navigator.of(context).pop();
      widget.onFinish?.call(false, 'Payment failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.paymentMethod.toUpperCase()} Payment'),
        backgroundColor: Theme.of(context).primaryColorLight,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            widget.onFinish?.call(false, 'Payment cancelled');
          },
          child: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class PaymentWebviewState extends BaseScreen<PaymentWebview> with WebviewMixin {
  int selectedIndex = 1;
  String? orderId;

  void handleUrlChanged(String url) {
    if (url.contains('/order-received/')) {
      final items = url.split('/order-received/');
      if (items.length > 1) {
        orderId = items[1].split('/')[0];
      }
    }

    if (url.contains('checkout/success')) {
      orderId = '0';
    }

    if (url.contains('thank-you')) {
      orderId = '0';
    }

    // shopify url final checkout
    if (url.contains('thank_you')) {
      orderId = '0';
    }

    /// BigCommerce.
    if (url.contains('/checkout/order-confirmation')) {
      orderId = '0';
    }

    /// Prestashop
    if (url.contains('/order-confirmation')) {
      var uri = Uri.parse(url);
      orderId = (uri.queryParameters['id_order'] ?? 0).toString();
    }

    /// Finally
    if (orderId != null) {
      widget.onFinish?.call(orderId);
      if (kPaymentConfig.showWebviewCheckoutSuccessScreen) {
        Navigator.of(context).pop();
      }
    }

    // Not sure about this case, maybe related to file lib/modules_ext/membership_ultimate/views/signup_screen.dart
    if (url.contains('/member-login/')) {
      orderId = '0';
      Navigator.of(context).pop();
      widget.onFinish?.call(orderId);
    }

    // opencart: exit webview when user press `continue` button after showing 'checkout/success' page. For example https://opencart-demo.mstore.io/index.php?route=checkout/success
    if (url.contains('common/home')) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    var checkoutMap = <dynamic, dynamic>{
      'url': '',
      'headers': <String, String>{}
    };

    if (widget.url != null) {
      checkoutMap['url'] = widget.url;
    } else {
      final paymentInfo = Services().widget.getPaymentUrl(context)!;
      checkoutMap['url'] = paymentInfo['url'];
      if (paymentInfo['headers'] != null) {
        checkoutMap['headers'] =
            Map<String, String>.from(paymentInfo['headers']);
      }
    }

    // if (widget.token != null) {
    //   checkoutMap['headers']['X-Shopify-Customer-Access-Token'] = widget.token;
    // }

    // // Enable webview payment plugin
    /// make sure to import 'payment_webview_plugin.dart';
    // return PaymentWebviewPlugin(
    //   url: checkoutMap['url'],
    //   headers: checkoutMap['headers'],
    //   onClose: widget.onClose,
    //   onFinish: widget.onFinish,
    // );

    return WebView(
      url: checkoutMap['url'] ?? '',
      headers: checkoutMap['headers'],
      onPageFinished: handleUrlChanged,
      onClosed: () {
        widget.onFinish?.call(orderId);
        widget.onClose?.call();
      },
    );
  }
}
