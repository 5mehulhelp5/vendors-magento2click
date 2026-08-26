import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../base/common_library.dart';
import '../utils.dart';
import '../utils/secure_storage.dart';

/// enable network proxy
const debugNetworkProxy = false;

/// Ceiling for any single HTTP request. Without it a stalled socket leaves the
/// caller awaiting forever, which the UI shows as an endless spinner. On expiry
/// we surface the same "offline" signal a dropped connection does — see the
/// [TimeoutException] handler in [makeRequest].
const kHttpRequestTimeout = Duration(seconds: 20);

class HttpBase extends http.BaseClient {
  final http.Client _client = http.Client();
  HttpBase();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    initProxyClient(MultiSite.mainSiteUrl ?? request.url);
    return _client.send(request);
  }
}

/// The human-readable reason out of an error response body, or null when the
/// body carries nothing worth showing.
///
/// The backends behind this app report errors as `{"message": "..."}`. Magento
/// additionally leaves `%1` / `%fieldName` placeholders in that string and
/// supplies the values in a `parameters` list or map — the same substitution
/// `MagentoHelper.getErrorMessage` performs for the statuses that already reach
/// it, repeated here because a 404 never gets that far.
///
/// A store behind a WAF or a proxy answers with an HTML error page rather than
/// JSON, and a parser dump is worse than saying nothing — so anything that is
/// not JSON carrying a non-empty `message` returns null and the caller falls
/// back to the status reason phrase.
String? parseBackendErrorMessage(String? body) {
  final trimmed = body?.trim() ?? '';
  if (!trimmed.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return null;
    final raw = decoded['message'];
    if (raw is! String || raw.trim().isEmpty) return null;

    var message = raw;
    final params = decoded['parameters'];
    if (params is List) {
      for (var i = 0; i < params.length; i++) {
        message = message.replaceAll('%${i + 1}', '${params[i]}');
      }
    } else if (params is Map) {
      params.forEach((key, value) {
        message = message.replaceAll('%$key', '$value');
      });
    }
    return message.trim();
  } catch (_) {
    // Not JSON after all — nothing safe to show.
    return null;
  }
}

/// What a 404 reports to the caller: the backend's own explanation when it sent
/// one, otherwise the status reason phrase.
@visibleForTesting
String notFoundError(http.Response response) =>
    parseBackendErrorMessage(response.body) ??
    response.reasonPhrase ??
    'Not Found';

/// Runs [request] and applies this file's convention that a failure surfaces as
/// a thrown String.
///
/// Set [allowNotFound] to receive a 404 as an ordinary [http.Response] — status
/// and body intact — instead of a throw. It is opt-in per call site, and the
/// default stays fail-closed on purpose: most callers of these helpers go
/// straight to `jsonDecode(res.body)` with no status check, so handing them a
/// 404 would have them parse an error payload as data (a product lookup would
/// crash, a profile save would write an empty address book, an order cancel
/// would report a cancellation that never happened).
///
/// Only pass it from a call site that branches on `statusCode` before reading
/// the body — currently the cart calls that recover from an expired quote.
@visibleForTesting
Future<http.Response> makeRequest(
  Future<http.Response> request, {
  bool allowNotFound = false,
}) async {
  final http.Response response;
  try {
    response = await request.timeout(kHttpRequestTimeout);
  } on TimeoutException {
    // A stalled or too-slow connection. Surface the same "offline" signal a
    // dropped socket does (matched by StringExtensions.isNoInternetError) so
    // the UI shows the retry screen instead of spinning indefinitely.
    // ignore: only_throw_errors
    throw 'No Internet Connection';
  } on SocketException catch (e) {
    // A genuine transport failure. Unchanged: the 404 case used to be funnelled
    // through here as a synthetic SocketException, which conflated "the server
    // answered 404" with "the socket failed".
    if (e.message.contains('Failed host lookup')) {
      // Matched by StringExtensions.isNoInternetError, which is what decides
      // whether the offline screen shows — keep the two in step.
      throw 'No Internet Connection';
    }
    throw e.message;
  }

  if (response.statusCode == 404 && !allowNotFound) {
    // Throws rather than returning the response, for the reason spelled out on
    // [allowNotFound] above. What changes is the message — the backend's own
    // explanation instead of the bare reason phrase, which is all a 404 used to
    // surface (e.g. the "Not Found" toast in 86d3rytm0, where Magento had
    // actually said "The product that was requested doesn't exist").
    //
    // The thrown value stays a String, as every other path here throws, so the
    // formatters that display it are unaffected.
    // ignore: only_throw_errors
    throw notFoundError(response);
  }
  return response;
}

/// The default http GET that support Logging
///
/// See [makeRequest] for [allowNotFound].
Future<http.Response> httpGet(
  Uri url, {
  Map<String, String>? headers,
  bool enableDio = false,
  String kWebProxy = '',
  bool allowNotFound = false,
}) async {
  initProxyClient(MultiSite.mainSiteUrl ?? url);
  final startTime = DateTime.now();
  if (enableDio) {
    try {
      final res = await Dio().get(url.toString(),
          options: Options(headers: headers, responseType: ResponseType.plain));
      printLog('GET:$url', startTime);
      final response = http.Response(res.toString(), res.statusCode!);
      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        final response =
            http.Response(e.response.toString(), e.response!.statusCode!);
        return response;
      } else {
        // ignore: only_throw_errors
        throw e.message ?? '';
      }
    }
  } else {
    var uri = url;
    if (foundation.kIsWeb) {
      final proxyURL = '$url';
      uri = Uri.parse(proxyURL);
    }
    printLog('♻️ GET:$url', startTime);
    return makeRequest(http.get(uri, headers: headers),
        allowNotFound: allowNotFound);
  }
}

/// The default http POST that support Logging
///
/// See [makeRequest] for [allowNotFound].
Future<http.Response> httpPost(Uri url,
    {Map<String, String>? headers,
    Object? body,
    bool enableDio = false,
    bool allowNotFound = false}) async {
  final startTime = DateTime.now();
  initProxyClient(MultiSite.mainSiteUrl ?? url);
  if (enableDio) {
    try {
      final res = await Dio().post(url.toString(),
          options: Options(headers: headers, responseType: ResponseType.plain),
          data: body);
      printLog('🔼 POST:$url', startTime);
      final response = http.Response(res.toString(), res.statusCode!);
      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        final response =
            http.Response(e.response.toString(), e.response!.statusCode!);
        return response;
      } else {
        // ignore: only_throw_errors
        throw e.message ?? 'error';
      }
    }
  } else {
    printLog('🔼 POST:$url', startTime);
    return makeRequest(http.post(url, headers: headers, body: body),
        allowNotFound: allowNotFound);
  }
}

/// The default http PUT that support Logging
///
/// See [makeRequest] for [allowNotFound].
Future<http.Response> httpPut(Uri url,
    {Map<String, String>? headers,
    Object? body,
    bool enableDio = false,
    bool allowNotFound = false}) async {
  final startTime = DateTime.now();
  initProxyClient(MultiSite.mainSiteUrl ?? url);
  if (enableDio) {
    try {
      final res = await Dio().put(url.toString(),
          options: Options(headers: headers, responseType: ResponseType.plain),
          data: body);
      printLog('🔼 PUT:$url', startTime);
      final response = http.Response(res.toString(), res.statusCode!);
      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        final response =
            http.Response(e.response.toString(), e.response!.statusCode!);
        return response;
      } else {
        // ignore: only_throw_errors
        throw e.message ?? 'error';
      }
    }
  } else {
    printLog('🔼 PUT:$url', startTime);
    return makeRequest(http.put(url, headers: headers, body: body),
        allowNotFound: allowNotFound);
  }
}

/// The default http PUT that support Logging
///
/// See [makeRequest] for [allowNotFound].
Future<http.Response> httpDelete(Uri url,
    {Map<String, String>? headers,
    Object? body,
    bool enableDio = false,
    bool allowNotFound = false}) async {
  final startTime = DateTime.now();
  initProxyClient(MultiSite.mainSiteUrl ?? url);
  if (enableDio) {
    try {
      final res = await Dio().delete(url.toString(),
          options: Options(headers: headers, responseType: ResponseType.plain),
          data: body);
      printLog('DELETE:$url', startTime);
      final response = http.Response(res.toString(), res.statusCode!);
      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        final response =
            http.Response(e.response.toString(), e.response!.statusCode!);
        return response;
      } else {
        // ignore: only_throw_errors
        throw e.message ?? 'error';
      }
    }
  } else {
    printLog('DELETE:$url', startTime);
    return makeRequest(http.delete(url, headers: headers, body: body),
        allowNotFound: allowNotFound);
  }
}

/// The default http PATCH that support Logging
///
/// See [makeRequest] for [allowNotFound].
Future<http.Response> httpPatch(Uri url,
    {Map<String, String>? headers,
    Object? body,
    bool enableDio = false,
    bool allowNotFound = false}) async {
  final startTime = DateTime.now();
  initProxyClient(MultiSite.mainSiteUrl ?? url);
  if (enableDio) {
    try {
      final res = await Dio().patch(url.toString(),
          options: Options(headers: headers, responseType: ResponseType.plain),
          data: body);
      printLog('PATCH:$url', startTime);
      final response = http.Response(res.toString(), res.statusCode!);
      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        final response =
            http.Response(e.response.toString(), e.response!.statusCode!);
        return response;
      } else {
        // ignore: only_throw_errors
        throw e.message ?? 'error';
      }
    }
  } else {
    printLog('PATCH:$url', startTime);
    return makeRequest(http.patch(url, headers: headers, body: body),
        allowNotFound: allowNotFound);
  }
}

void initProxyClient(Uri url) {
  if (!kDebugMode) {
    return;
  }
  EasyDebounce.debounce('initProxyClient', const Duration(seconds: 2),
      () async {
    try {
      final temp = url.toString();
      final proxyUrl = temp.substring(0, temp.indexOf(url.path));

      var httpClient = await CommonLibrary().initHttpClient() ?? '';
      if (httpClient.isEmpty) {
        _handleError();
        return;
      }

      var cachedHttpClient = await getHttpClientResult();
      if (cachedHttpClient.isEmpty ||
          _combineUrl(proxyUrl, httpClient) != cachedHttpClient) {
        final result = await Videos.getWorkingProxyLink(proxyUrl, httpClient);

        if (result.statusCode == 200) {
          await setHttpClientResult(_combineUrl(proxyUrl, httpClient));
          await setLastInitTime(DateTime.now().millisecondsSinceEpoch);
        }

        if (result.statusCode == 403 || result.body.contains('message')) {
          throw ProxyException('${jsonDecode(result.body)['message']}');
        }
      }
    } on ProxyException catch (e) {
      debugPrint(e.message);
      exit(0);
    } catch (_) {}
  });
}

String _combineUrl(proxyUrl, httpClient) {
  return '$proxyUrl$httpClient';
}

void _handleError() {
  final msg = EncodeUtils.decode(
    'Cgp8IHwgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0gfCB8CnwgfCDimqDvuI8gUGxlYXNlIHByb3ZpZGUgeW91ciBwdXJjaGFzZSBjb2RlIGluIGNvbmZpZ3MvZW52LnByb3BzIHwgfAp8IHwgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0gfCB8Cgo=',
  );
  throw ProxyException(msg);
}

class ProxyException implements Exception {
  final String message;

  ProxyException(this.message);
}

class MultiSite {
  static Uri? mainSiteUrl;
}
