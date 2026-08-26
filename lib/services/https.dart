import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:logger/logger.dart';

import 'package:inspireui/inspireui.dart';
import '../common/config.dart';
import 'http_cache_manager.dart';

const kWebProxy = '';
const isBuilder = false;

/// The default http GET that support Logging
Future<http.Response> httpCache(
  Uri url, {
  Map<String, String>? headers,
  bool refreshCache = false,
  bool shortLived = false,
}) async {
  final startTime = DateTime.now();

  var uri = url;
  if (foundation.kIsWeb) {
    final proxyURL = '$kWebProxy$url';
    uri = Uri.parse(proxyURL);
  }

  // Catalog data (product lists) uses a short-TTL store that is separate from
  // the image cache; everything else uses the standard 1h store.
  final manager = shortLived ? CatalogCacheManager() : HttpCacheManager();

  if (refreshCache) {
    await manager.removeFile(uri.toString());
    printLog('🔴 REMOVE CACHE:$url', startTime);
  }

  // Enable default on FluxBuilder
  if (kAdvanceConfig.httpCache || isBuilder) {
    try {
      var file = await manager.getSingleFile(
        uri.toString(),
        headers: (headers ?? {})..addAll({'Content-Encoding': 'gzip'}),
      );

      if (await file.exists()) {
        var res = await file.readAsString();
        var fileSize = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);

        printLog('📥 GET CACHE($fileSize mb):$url', startTime);
        return http.Response(res, 200);
      }
      return http.Response('', 404);
    } catch (e) {
      // printLog(trace);
      printLog('CACHE ISSUE: ${e.toString()}', startTime, Level.debug);
    }
  }
  return httpGet(uri, headers: headers);
}
