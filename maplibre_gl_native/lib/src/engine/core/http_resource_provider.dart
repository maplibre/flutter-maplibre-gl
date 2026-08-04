import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

import 'http_redirect_policy.dart';

/// Serves http(s) resource requests of the native engine through Dart's own
/// HTTP stack (`dart:io` [HttpClient]).
///
/// NOT installed by default. The built-in Rust HTTP client serves all
/// requests since upstream maplibre-native-ffi#461 fixed its Android TLS
/// verification (rustls-platform-verifier#221 reported CRL-only certificates,
/// most public CAs since they retired OCSP in 2025, as "invalid peer
/// certificate: Revoked"; the vendored fix follows the system trust manager's
/// policy, like OkHttp).
///
/// This provider remains for one job: regex-filtered custom headers
/// (`setCustomHeaders` with urlFilters). Plain headers ride the native
/// client's header transforms (upstream #509, prefix rules per scheme), but
/// a regex filter needs a decision per URL, which only this fetch path can
/// make. It is installed lazily when such a call arrives, or up front with
/// MLN_DART_HTTP=true (the A/B arm; see the README's debug knobs).
class HttpResourceProvider {
  HttpResourceProvider._();

  // Cap concurrent connections per host like the platform SDK HTTP stacks
  // (OkHttp allows 5 per host): an uncapped burst at style load (tilejson +
  // tiles + glyphs at once) trips aggressive rate limiters, e.g. the 429s of
  // demotiles.maplibre.org.
  //
  // The timeouts exist because every in-flight request pins its native
  // ResourceRequestHandle: dart:io has no default connection or response
  // deadline, so one hung connection would hold that handle for the rest of
  // the process. The connection timeout matches OkHttp's default (10 s); the
  // whole-exchange cap in [_fetch] is generous enough for a slow tile on a
  // bad link.
  static final HttpClient _client = HttpClient()
    ..userAgent = 'flutter-maplibre-gl/maplibre_gl_native'
    ..maxConnectionsPerHost = 8
    ..connectionTimeout = const Duration(seconds: 10);

  /// Deadline for one whole request/response exchange, headers to last byte.
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Redirect hop cap, matching dart:io's own default (`maxRedirects`).
  static const int _maxRedirects = 5;

  static Map<String, String> _globalHeaders = const {};
  static Map<String, String> _customHeaders = const {};
  static List<RegExp> _customFilters = const [];
  static bool _customFiltered = false;

  /// Replaces the app-configured headers applied to outgoing requests.
  ///
  /// [global] comes from `MapLibreGlNative.setGlobalHttpHeaders`, [custom]
  /// from the per-map `setCustomHeaders` together with its regex
  /// [customUrlFilters] (when non-empty, a request URL must match one of them
  /// for the custom headers to apply). The two arrive as separate slots so
  /// one setter can never wipe the other; on a name collision the custom
  /// header wins, the precedence documented on both public APIs. An empty
  /// map clears its own slot only.
  static void setHeaders({
    required Map<String, String> global,
    required Map<String, String> custom,
    required List<String> customUrlFilters,
  }) {
    _globalHeaders = Map.unmodifiable(global);
    _customHeaders = Map.unmodifiable(custom);
    // The patterns are arbitrary app input: one invalid regex must neither
    // escape into the command handler (headers silently stop applying with
    // nothing but a dead engine command to show for it) nor disable the
    // valid patterns next to it. _customFiltered records that filtering was
    // requested even when every pattern failed to compile, because falling
    // back to an empty filter list would WIDEN the headers to every URL —
    // the opposite of what the app asked for.
    _customFiltered = customUrlFilters.isNotEmpty;
    final filters = <RegExp>[];
    for (final pattern in customUrlFilters) {
      try {
        filters.add(RegExp(pattern));
      } on FormatException catch (error) {
        debugPrint(
          '[maplibre_gl_native] ignoring invalid custom-header url filter '
          '"$pattern": $error',
        );
      }
    }
    _customFilters = List.unmodifiable(filters);
  }

  /// The app-configured headers applicable to one request URL: the globals,
  /// overlaid by the custom headers when the URL passes their filters.
  static Map<String, String> _appHeadersFor(String url) {
    final customApplies =
        _customHeaders.isNotEmpty &&
        (!_customFiltered || _customFilters.any((f) => f.hasMatch(url)));
    return {..._globalHeaders, if (customApplies) ..._customHeaders};
  }

  static bool _installed = false;

  /// Whether the provider currently serves http(s) requests. Once true, every
  /// header set must flow through [setHeaders]: requests routed here never
  /// reach the native client's header transforms.
  static bool get isInstalled => _installed;

  /// Installs the provider on [runtime]: styles, tiles, glyphs, and sprites
  /// requested over http/https are then fetched by Dart. Idempotent. There is
  /// no uninstall; headers cleared later just stop being applied.
  static void install(mln.RuntimeHandle runtime) {
    if (_installed) {
      return;
    }
    _installed = true;
    runtime.setResourceProvider(
      // Not const: the binding copies the route list into an unmodifiable
      // view, so the constructor cannot be const.
      mln.ResourceProvider(
        routes: const [
          mln.ResourceProviderRoute(url: 'http://', matchPrefix: true),
          mln.ResourceProviderRoute(url: 'https://', matchPrefix: true),
        ],
        callback: _onRequest,
      ),
    );
  }

  static void _onRequest(
    mln.ResourceRequest request,
    mln.ResourceRequestHandle handle,
  ) {
    // The callback must not block: fetch asynchronously and complete the
    // handle later. Everything stays on the engine isolate that installed
    // the provider (the handle is isolate-affine).
    unawaited(_fetch(request, handle));
  }

  static Future<void> _fetch(
    mln.ResourceRequest request,
    mln.ResourceRequestHandle handle,
  ) async {
    try {
      // The timeout covers the whole exchange, redirect hops included: a
      // stalled response body pins the native handle just as surely as a
      // connection that never opens.
      final (response, bytes) = await () async {
        final originalUrl = Uri.parse(request.resolvedUrl);
        var url = originalUrl;
        var sendCustomHeaders = true;
        var redirects = 0;
        while (true) {
          final httpRequest = await _client.getUrl(url);
          // dart:io's automatic redirect handling copies every request
          // header onto the redirected request, even toward another host,
          // which would leak Authorization/API-key custom headers
          // cross-origin. Redirects are followed manually instead
          // ([nextRedirectHop]) so the app-configured headers are withheld
          // as soon as the chain leaves the original origin, and insecure
          // https-to-http downgrades are refused outright.
          httpRequest.followRedirects = false;
          if (sendCustomHeaders) {
            _appHeadersFor(url.toString()).forEach(httpRequest.headers.set);
          }
          // The cache validators and the Range header are the provider's
          // own, not app secrets: they ride every hop so the final host can
          // still answer 304 / 206 (servers issuing the redirects in between
          // simply ignore them).
          final priorEtag = request.priorEtag;
          final priorModifiedUnixMs = request.priorModifiedUnixMs;
          if (priorEtag != null) {
            httpRequest.headers.set(HttpHeaders.ifNoneMatchHeader, priorEtag);
          } else if (priorModifiedUnixMs != null) {
            httpRequest.headers.set(
              HttpHeaders.ifModifiedSinceHeader,
              HttpDate.format(
                DateTime.fromMillisecondsSinceEpoch(
                  priorModifiedUnixMs,
                  isUtc: true,
                ),
              ),
            );
          }
          final range = request.range;
          if (range != null) {
            httpRequest.headers.set(
              HttpHeaders.rangeHeader,
              'bytes=${range.start}-${range.end}',
            );
          }
          final response = await httpRequest.close();
          final hop = nextRedirectHop(
            statusCode: response.statusCode,
            location: response.headers.value(HttpHeaders.locationHeader),
            requestUrl: url,
            originalUrl: originalUrl,
          );
          if (hop == null) {
            return (response, await _readBytes(response));
          }
          if (++redirects > _maxRedirects) {
            throw RedirectRefusedException(
              'more than $_maxRedirects redirects for $originalUrl',
            );
          }
          // The redirect body is unused; drain it so the connection returns
          // to the pool instead of counting against maxConnectionsPerHost
          // until garbage collection.
          await response.drain<void>();
          url = hop.target;
          sendCustomHeaders = hop.sendCustomHeaders;
        }
      }().timeout(_requestTimeout);
      if (handle.isCancelled) {
        handle.close();
        return;
      }
      if (response.statusCode >= 400) {
        // Tile-level failures produce no visible map event, so surface them.
        debugPrint(
          '[maplibre_gl_native] HTTP ${response.statusCode} '
          'for ${request.resolvedUrl}',
        );
      }
      _complete(handle, _toResourceResponse(response, bytes));
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] HTTP fetch failed: '
        '${request.resolvedUrl}: $error',
      );
      if (handle.isCancelled) {
        handle.close();
        return;
      }
      final reason =
          error is SocketException ||
              error is HandshakeException ||
              error is TlsException ||
              error is HttpException ||
              error is TimeoutException
          ? mln.ResourceErrorReason.connection
          : mln.ResourceErrorReason.other;
      _complete(
        handle,
        mln.ResourceResponse(
          status: mln.ResourceResponseStatus.error,
          errorReason: reason,
          errorMessage: '$error',
        ),
      );
    }
  }

  /// Completes [handle], tolerating the engine cancelling the request
  /// concurrently: the isCancelled checks above cannot fully close the race,
  /// and completing a natively cancelled request fails with invalidState. An
  /// exception escaping here would kill the whole engine isolate over one
  /// stale tile. A failed complete leaves the native reference alive, so it
  /// is released with [mln.ResourceRequestHandle.close].
  static void _complete(
    mln.ResourceRequestHandle handle,
    mln.ResourceResponse response,
  ) {
    try {
      handle.complete(response);
    } on mln.MaplibreException catch (error) {
      debugPrint(
        '[maplibre_gl_native] resource request completion dropped: $error',
      );
      handle.close();
    }
  }

  static Future<Uint8List> _readBytes(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    await response.forEach(builder.add);
    return builder.takeBytes();
  }

  static mln.ResourceResponse _toResourceResponse(
    HttpClientResponse response,
    Uint8List bytes,
  ) {
    final headers = response.headers;
    final etag = headers.value(HttpHeaders.etagHeader);
    final cacheControl = headers.value(HttpHeaders.cacheControlHeader) ?? '';
    final mustRevalidate = cacheControl.contains('must-revalidate');
    final modifiedUnixMs = _unixMs(
      _parseHttpDate(headers.value(HttpHeaders.lastModifiedHeader)),
    );
    // Prefer Cache-Control max-age over the Expires header, like the native
    // HTTP file sources do.
    var expiresUnixMs = _unixMs(
      _parseHttpDate(headers.value(HttpHeaders.expiresHeader)),
    );
    final maxAge = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
    if (maxAge != null) {
      expiresUnixMs = DateTime.now()
          .add(Duration(seconds: int.parse(maxAge.group(1)!)))
          .toUtc()
          .millisecondsSinceEpoch;
    }

    switch (response.statusCode) {
      case HttpStatus.ok || HttpStatus.partialContent:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.ok,
          bytes: bytes,
          etag: etag,
          modifiedUnixMs: modifiedUnixMs,
          expiresUnixMs: expiresUnixMs,
          mustRevalidate: mustRevalidate,
        );
      case HttpStatus.noContent:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.noContent,
          etag: etag,
          modifiedUnixMs: modifiedUnixMs,
          expiresUnixMs: expiresUnixMs,
          mustRevalidate: mustRevalidate,
        );
      case HttpStatus.notModified:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.notModified,
          etag: etag,
          modifiedUnixMs: modifiedUnixMs,
          expiresUnixMs: expiresUnixMs,
          mustRevalidate: mustRevalidate,
        );
      case HttpStatus.notFound || HttpStatus.gone:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.error,
          errorReason: mln.ResourceErrorReason.notFound,
          errorMessage: 'not found',
        );
      case HttpStatus.tooManyRequests:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.error,
          errorReason: mln.ResourceErrorReason.rateLimit,
          errorMessage: 'rate limited',
          retryAfterUnixMs: _retryAfterUnixMs(
            headers.value('retry-after'),
          ),
        );
      default:
        return mln.ResourceResponse(
          status: mln.ResourceResponseStatus.error,
          errorReason: mln.ResourceErrorReason.server,
          errorMessage: 'HTTP status ${response.statusCode}',
        );
    }
  }

  static DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } on Exception {
      return null;
    }
  }

  static int? _unixMs(DateTime? value) => value?.toUtc().millisecondsSinceEpoch;

  static int? _retryAfterUnixMs(String? retryAfter) {
    if (retryAfter == null) return null;
    // Degenerate values (demotiles always sends "retry-after: 0", and a
    // date header can lie in the past) must NOT be forwarded: the engine
    // computes `retryAfter - now` and a non-positive timeout makes it retry
    // rate-limited requests immediately in a tight loop, hammering the
    // server and keeping the client rate-limited indefinitely. Returning
    // null selects the engine's default backoff instead
    // (DEFAULT_RATE_LIMIT_TIMEOUT, 5 s).
    final seconds = int.tryParse(retryAfter);
    if (seconds != null) {
      if (seconds <= 0) return null;
      return DateTime.now()
          .add(Duration(seconds: seconds))
          .toUtc()
          .millisecondsSinceEpoch;
    }
    final unixMs = _unixMs(_parseHttpDate(retryAfter));
    if (unixMs == null || unixMs <= DateTime.now().millisecondsSinceEpoch) {
      return null;
    }
    return unixMs;
  }
}
