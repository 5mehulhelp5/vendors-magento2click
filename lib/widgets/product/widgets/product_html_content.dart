import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../services/service_config.dart';

/// Renders a product's `description` / `short_description` markup as HTML.
///
/// These attributes are authored in Page Builder and routinely carry images and
/// video. Flattening them to plain text — which is what the product page used
/// to do — dropped every `<img>` and `<video>`, so the media the merchant added
/// simply never appeared in the app while the website showed it.
///
/// The markup is inline-styled Page Builder output, so it is rendered by a
/// webview sized to its own content rather than re-implemented as widgets: the
/// block sits inline in the scrolling product page and never scrolls itself.
class ProductHtmlContent extends StatefulWidget {
  final String html;

  /// Colour behind the content, matched to the surrounding card so the block
  /// doesn't show as a white rectangle on a tinted background.
  final Color? backgroundColor;

  /// Text colour, so the content inherits the app theme rather than defaulting
  /// to black on a dark background.
  final Color? textColor;

  const ProductHtmlContent(
    this.html, {
    super.key,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<ProductHtmlContent> createState() => _ProductHtmlContentState();
}

class _ProductHtmlContentState extends State<ProductHtmlContent> {
  WebViewController? _controller;

  /// Starts small so the block doesn't reserve a screenful of blank space
  /// before the content reports its real height.
  double _height = 1;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant ProductHtmlContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _build();
    }
  }

  void _build() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor ?? Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterContentHeight',
        onMessageReceived: (message) {
          final value = double.tryParse(message.message);
          // Images and video decode after first paint, so the height is
          // reported repeatedly (see the ResizeObserver below) rather than
          // measured once on load — measuring once left the media clipped.
          if (value != null && value > 0 && mounted && value != _height) {
            setState(() => _height = value);
          }
        },
      )
      ..loadHtmlString(_document, baseUrl: ServerConfig().url);
    setState(() => _controller = controller);
  }

  String get _document {
    final bg = widget.backgroundColor ?? Colors.transparent;
    final fg = widget.textColor ?? const Color(0xFF111827);
    return '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  html,body{margin:0;padding:0;overflow-x:hidden;overflow-y:hidden;
    background:${_css(bg)};color:${_css(fg)};
    font-family:-apple-system,Roboto,sans-serif;font-size:14px;line-height:1.6}
  img,video,iframe,table{max-width:100%!important;height:auto}
  /* Page Builder rows are written for a desktop grid; let them wrap. */
  .pagebuilder-column-line,[data-content-type="column-line"]{flex-wrap:wrap!important}
  .pagebuilder-column,[data-content-type="column"]{width:100%!important;flex-basis:100%!important}
</style>
</head>
<body dir="auto">
${resolveDirectives(widget.html)}
<script>
  function report(){
    FlutterContentHeight.postMessage(String(document.body.scrollHeight));
  }
  new ResizeObserver(report).observe(document.body);
  window.addEventListener('load', report);
  document.querySelectorAll('img,video').forEach(function(el){
    el.addEventListener('load', report);
    el.addEventListener('loadedmetadata', report);
    el.addEventListener('error', report);
  });
  report();
</script>
</body></html>''';
  }

  static String _css(Color c) =>
      'rgba(${(c.r * 255).round()},${(c.g * 255).round()},'
      '${(c.b * 255).round()},${c.a})';

  /// Expands the `{{media url=...}}` / `{{store url=...}}` directives Magento
  /// stores in Page Builder and WYSIWYG content. They are resolved by the
  /// storefront renderer, never by the REST payload, so an `<img>` reaches the
  /// app with a literal `{{media url=…}}` for its `src` and can't load.
  static String resolveDirectives(String markup, [String? baseUrl]) {
    if (!markup.contains('{{')) return markup;

    final domain = (baseUrl ?? ServerConfig().url).replaceAll(RegExp(r'/+$'), '');
    final storeBase = '$domain/';
    final mediaBase = '$domain/media/';

    final result = StringBuffer();
    var rest = markup;
    while (true) {
      final open = rest.indexOf('{{');
      final close = open < 0 ? -1 : rest.indexOf('}}', open);
      if (open < 0 || close < 0) {
        result.write(rest);
        break;
      }
      result.write(rest.substring(0, open));
      final directive = rest.substring(open + 2, close).trim();
      if (directive.startsWith('media ')) {
        result.write(mediaBase + _directiveUrl(directive));
      } else if (directive.startsWith('store ')) {
        result.write(storeBase + _directiveUrl(directive));
      } else {
        result.write(rest.substring(open, close + 2));
      }
      rest = rest.substring(close + 2);
    }
    return result.toString();
  }

  /// Pulls the `url=…` value, quoted or not, out of a directive body.
  static String _directiveUrl(String directive) {
    final equals = directive.indexOf('=');
    if (equals < 0) return '';
    var url = directive.substring(equals + 1).trim();
    if (url.length > 1 &&
        url[0] == url[url.length - 1] &&
        (url[0] == '"' || url[0] == "'")) {
      url = url.substring(1, url.length - 1);
    }
    // Media paths are stored relative to the media root.
    return url.startsWith('/') ? url.substring(1) : url;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return SizedBox(
      height: _height,
      child: WebViewWidget(controller: controller),
    );
  }
}
