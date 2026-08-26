import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    hide HttpGetResponse;
// ignore: implementation_imports
import 'package:flutter_cache_manager/src/web/mime_converter.dart';
import 'package:http/http.dart' as http;
import 'package:inspireui/inspireui.dart';

// Time keep the file without a cache-control header
const Duration keepDuration = Duration(hours: 1);

// Catalog API responses (product lists) shift intraday as price/stock change,
// so they cache only briefly — long enough that opening a product and coming
// back re-uses the list instantly, short enough that a stale price self-heals.
const Duration catalogKeepDuration = Duration(minutes: 5);

class HttpFileService extends FileService {
  final http.Client _httpClient;

  /// How long a fetched file stays fresh when the response carries no
  /// `Cache-Control`. Overridable so a short-lived catalog cache can pass a
  /// few minutes instead of the [keepDuration] default.
  final Duration keep;

  HttpFileService({http.Client? httpClient, this.keep = keepDuration})
      : _httpClient = httpClient ?? http.Client();

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final req = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      req.headers.addAll(headers);
    }
    final httpResponse = await _httpClient.send(req);

    return HttpGetResponse(httpResponse, keep);
  }
}

class HttpGetResponse implements FileServiceResponse {
  HttpGetResponse(this._response, [this._keep = keepDuration]);

  final DateTime _receivedTime = DateTime.now();

  final http.StreamedResponse _response;

  /// Fallback freshness window when the response has no `Cache-Control`.
  final Duration _keep;

  @override
  int get statusCode => _response.statusCode;

  String? _header(String name) {
    return _response.headers[name];
  }

  @override
  Stream<List<int>> get content => _response.stream;

  @override
  int? get contentLength => _response.contentLength;

  @override
  DateTime get validTill {
    var ageDuration = Duration(milliseconds: _keep.inMilliseconds);
    final controlHeader = _header(HttpHeaders.cacheControlHeader);
    if (controlHeader != null) {
      final controlSettings = controlHeader.split(',');
      for (final setting in controlSettings) {
        final sanitizedSetting = setting.trim().toLowerCase();
        if (sanitizedSetting == 'no-cache') {
          ageDuration = const Duration();
        }
        if (sanitizedSetting.startsWith('max-age=')) {
          var validSeconds = int.tryParse(sanitizedSetting.split('=')[1]) ?? 0;
          if (validSeconds > 0) {
            ageDuration = Duration(seconds: validSeconds);
          }
        }
      }
    }

    return _receivedTime.add(ageDuration);
  }

  @override
  String? get eTag => _header(HttpHeaders.etagHeader);

  @override
  String get fileExtension {
    var fileExtension = '';
    final contentTypeHeader = _header(HttpHeaders.contentTypeHeader);
    if (contentTypeHeader != null) {
      final contentType = ContentType.parse(contentTypeHeader);
      fileExtension = contentType.fileExtension;
    }
    return fileExtension;
  }
}

class HttpCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData';

  static final HttpCacheManager _instance = HttpCacheManager._();
  factory HttpCacheManager() {
    return _instance;
  }

  HttpCacheManager._()
      : super(Config(
          key,
          fileService: HttpFileService(httpClient: HttpBase()),
        ));
}

/// Short-lived, image-free cache for catalog API responses (product lists).
/// Kept separate from [HttpCacheManager] so evicting stale product lists never
/// touches the image cache, and [catalogKeepDuration] bounds price/stock
/// staleness while still making back-navigation instant.
class CatalogCacheManager extends CacheManager {
  static const key = 'catalogApiCache';

  static final CatalogCacheManager _instance = CatalogCacheManager._();
  factory CatalogCacheManager() {
    return _instance;
  }

  CatalogCacheManager._()
      : super(Config(
          key,
          stalePeriod: catalogKeepDuration,
          fileService: HttpFileService(
              httpClient: HttpBase(), keep: catalogKeepDuration),
        ));
}
