import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

/// Serves every http(s) resource request of the native engine through Dart's
/// own HTTP stack (`dart:io` [HttpClient]).
///
/// The C library ships a Rust HTTP client whose TLS verification
/// (rustls-platform-verifier) rejected valid certificates on some Android
/// devices during the spike ("invalid peer certificate: Revoked"). Fetching
/// from Dart sidesteps that stack entirely, reuses the platform trust store
/// the rest of the app already relies on, and is the natural seam for custom
/// HTTP headers (`setHttpHeaders`) later.
///
/// Requires the prefix-wildcard route patch in the pinned maplibre-native-ffi
/// build (route URLs ending in `*` match by prefix); see the package README.
class HttpResourceProvider {
  HttpResourceProvider._();

  // Cap concurrent connections per host like the platform SDK HTTP stacks
  // (OkHttp allows 5 per host): an uncapped burst at style load (tilejson +
  // tiles + glyphs at once) trips aggressive rate limiters, e.g. the 429s of
  // demotiles.maplibre.org.
  static final HttpClient _client = HttpClient()
    ..userAgent = 'flutter-maplibre-gl/maplibre_gl_native (spike)'
    ..maxConnectionsPerHost = 8;

  static Map<String, String> _headers = const {};
  static List<RegExp> _headerFilters = const [];

  /// Sets the custom headers applied to outgoing requests (setHttpHeaders /
  /// setCustomHeaders). [urlFilters] are regex patterns; when non-empty a
  /// request URL must match one of them for the headers to apply. An empty
  /// [headers] map clears.
  static void setHeaders(
    Map<String, String> headers, {
    List<String> urlFilters = const [],
  }) {
    _headers = Map.unmodifiable(headers);
    _headerFilters = [for (final pattern in urlFilters) RegExp(pattern)];
  }

  /// Installs the provider on [runtime]: styles, tiles, glyphs, and sprites
  /// requested over http/https are then fetched by Dart.
  static void install(mln.RuntimeHandle runtime) {
    runtime.setResourceProvider(
      const mln.ResourceProvider(
        routes: [
          mln.ResourceProviderRoute(url: 'http://*'),
          mln.ResourceProviderRoute(url: 'https://*'),
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
    // handle later. Everything stays on the main isolate (the handle is
    // isolate-affine).
    unawaited(_fetch(request, handle));
  }

  static Future<void> _fetch(
    mln.ResourceRequest request,
    mln.ResourceRequestHandle handle,
  ) async {
    try {
      final httpRequest = await _client.getUrl(Uri.parse(request.url));
      if (_headers.isNotEmpty &&
          (_headerFilters.isEmpty ||
              _headerFilters.any((f) => f.hasMatch(request.url)))) {
        _headers.forEach(httpRequest.headers.set);
      }
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
      final bytes = await _readBytes(response);
      if (handle.isReleased) return;
      if (handle.isCancelled) {
        handle.close();
        return;
      }
      if (response.statusCode >= 400) {
        // Tile-level failures produce no visible map event, so surface them.
        debugPrint(
          '[maplibre_gl_native] HTTP ${response.statusCode} '
          'for ${request.url}',
        );
      }
      handle.complete(_toResourceResponse(response, bytes));
    } catch (error) {
      debugPrint('[maplibre_gl_native] HTTP fetch failed: '
          '${request.url}: $error');
      if (handle.isReleased) return;
      final reason =
          error is SocketException ||
              error is HandshakeException ||
              error is TlsException ||
              error is HttpException
          ? mln.ResourceErrorReason.connection
          : mln.ResourceErrorReason.other;
      handle.complete(
        mln.ResourceResponse(
          status: mln.ResourceResponseStatus.error,
          errorReason: reason,
          errorMessage: '$error',
        ),
      );
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
        return const mln.ResourceResponse(
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
