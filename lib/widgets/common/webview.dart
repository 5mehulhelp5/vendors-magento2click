import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../common/config.dart';
import '../../common/constants.dart';
import '../../common/tools.dart';
import '../../generated/l10n.dart';
import '../../models/entities/user.dart';
import '../../models/user_model.dart';
import '../../screens/common/app_bar_mixin.dart';
import '../../services/index.dart';

mixin WebviewMixin {
  Future<bool> overrideWebNavigation(String url) async {
    var isHttp = 'http';
    if (url.startsWith(isHttp)) {
      return false;
    }

    if (url.startsWith('intent://') && url.contains('scheme=')) {
      final intentInfo = url.substring(url.indexOf('scheme='));
      final scheme = intentInfo.substring(
          intentInfo.indexOf('scheme=') + 7, intentInfo.indexOf(';'));
      final newUrl = url.replaceFirst('intent://', '$scheme://');
      await Tools.launchURL(
        newUrl,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      return true;
    }

    await Tools.launchURL(
      url,
      mode: LaunchMode.externalNonBrowserApplication,
    );

    return true;
  }

  Future<NavigationDecision> getNavigationDelegate(NavigationRequest request) async {
    final url = request.url;
    printLog('[WebView] getNavigationDelegate: $url');
    final overridden = await overrideWebNavigation(url);

    return overridden ? NavigationDecision.prevent : NavigationDecision.navigate;
  }
}

class WebView extends StatefulWidget {
  final String? url;
  final String? title;
  final AppBar? appBar;
  final bool enableForward;
  final bool enableBackward;
  final bool enableClose;
  final void Function(String)? onPageFinished;
  final Function? onClosed;
  final bool auth;
  final String script;
  final Map<String, String>? headers;
  final String? routeName;
  final void Function(dynamic controller)? onWebViewCreated;

  const WebView({
    Key? key,
    this.title,
    required this.url,
    this.appBar,
    this.onPageFinished,
    this.onClosed,
    this.auth = false,
    this.script = '',
    this.headers,
    this.enableForward = true,
    this.enableBackward = true,
    this.enableClose = true,
    this.routeName,
    this.onWebViewCreated
  }) : super(key: key);

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> with WebviewMixin, AppBarMixin {
  bool _isLoading = true;
  String html = '';

  late final WebViewController _controller;

  // listen: false — this is read once in initState() (via _initWebView) to
  // build the initial request URL, and Provider forbids listen: true lookups
  // before initState() has completed (throws "dependOnInheritedElement...
  // was called before initState() completed", silently swallowed by the
  // app's global ErrorWidget.builder into a blank screen).
  User? get user => Provider.of<UserModel>(context, listen: false).user;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
    //  WebView.platform = AndroidWebView();
    } else if (Platform.isIOS) {
     // WebView.platform = CupertinoWebView();
    }

    if (isMacOS || isWindow) {
      httpGet(widget.url.toString().toUri()!).then((response) {
        setState(() {
          html = response.body;
        });
      });
    } else {
      _initWebView();
    }
  }

  void _initWebView() {
    var url = widget.url ?? '';
    final uri = url.toUri();
    if (uri != null && uri.scheme.isEmpty) {
      url = 'https://$url';
    }

    if (kAdvanceConfig.alwaysClearWebViewCache) {
      url = '$url${url.paramSymbol}dummy=${DateTime.now().millisecondsSinceEpoch}';
    }

    // `?cookie=<base64>` is an mstore WordPress-plugin convention: only a
    // Woo/WordPress backend has a handler that reads it back and restores the
    // session. Every other caller in the app already gates it on store type
    // (NavigateTools.navigateToWebView), but this one did not — so on Magento
    // it appended the customer's REST bearer token to storefront URLs, where it
    // authenticated nothing (Magento just carries the param through its
    // redirects) and leaked a live credential into request logs and Referer
    // headers. Gate it the same way.
    if (widget.auth &&
        (ServerConfig().isWooType || ServerConfig().isWordPress) &&
        (user?.cookie?.isNotEmpty ?? false)) {
      var base64Str = EncodeUtils.encodeCookie(user!.cookie!);
      url = '$url${url.paramSymbol}cookie=$base64Str';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => getNavigationDelegate(request),
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            final script = widget.script.isEmptyOrNull
                ? kAdvanceConfig.webViewScript
                : widget.script;
            if (script.isNotEmpty) {
              _controller.runJavaScript(script);
            }
            if (widget.onPageFinished != null) {
              widget.onPageFinished!(url);
            }
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Never leave the user stuck on a blank loading overlay if the page
            // fails or hangs (slow network, load error, redirect) — reveal the
            // webview so its content or the browser error page is visible.
            printLog(
                '[WebView] resource error: ${error.errorCode} ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      // Forward `headers`: the field was declared and accepted by the
      // constructor but never read, so any caller passing headers (the obvious
      // way to authenticate a webview) would compile, look correct and send
      // nothing.
      ..loadRequest(Uri.parse(url), headers: widget.headers ?? const {});
    if(widget.onWebViewCreated != null)
    widget.onWebViewCreated!(_controller);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isMacOS || isWindow) {
      return renderScaffold(
        routeName: widget.routeName ?? RouteList.webview,
        secondAppBar: widget.appBar ??
            AppBar(
              backgroundColor: Theme.of(context).colorScheme.background,
              elevation: 0.0,
              centerTitle: true,
              title: Text(
                widget.title ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              actions: [
                if (widget.enableClose)
                  IconButton(
                    onPressed: () {
                      widget.onClosed?.call();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close, size: 20),
                  ),
                const SizedBox(width: 10),
              ],
              leading: Builder(
                builder: (context) {
                  return Row(
                    children: [
                      if (widget.enableBackward)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 20),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      if (widget.enableForward)
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_forward_ios, size: 20),
                        ),
                    ],
                  );
                },
              ),
            ),
        child: SingleChildScrollView(child: Container()),
      );
    }

    return renderScaffold(
      routeName: widget.routeName ?? RouteList.webview,
      secondAppBar: widget.appBar ??
          AppBar(
            backgroundColor: Theme.of(context).colorScheme.background,
            elevation: 0.0,
            centerTitle: true,
            title: Text(
              widget.title ?? '',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            leadingWidth: 150,
            actions: [
              if (widget.enableClose)
                IconButton(
                  onPressed: () {
                    widget.onClosed?.call();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
              const SizedBox(width: 10),
            ],
            leading: Builder(
              builder: (context) {
                return Row(
                  children: [
                    if (widget.enableBackward)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: () async {
                          if (await _controller.canGoBack()) {
                            await _controller.goBack();
                          } else if (!widget.enableClose && Navigator.canPop(context)) {
                            widget.onClosed?.call();
                            Navigator.of(context).pop();
                          } else {
                            Tools.showSnackBar(
                              ScaffoldMessenger.of(context),
                              S.of(context).noBackHistoryItem,
                            );
                          }
                        },
                      ),
                    if (widget.enableForward)
                      IconButton(
                        onPressed: () async {
                          if (await _controller.canGoForward()) {
                            await _controller.goForward();
                          } else {
                            Tools.showSnackBar(
                              ScaffoldMessenger.of(context),
                              S.of(context).noForwardHistoryItem,
                            );
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_ios, size: 20),
                      ),
                  ],
                );
              },
            ),
          ),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) Center(child: kLoadingWidget(context)),
        ],
      ),
    );
  }
}