/// Redirect-following policy of the Dart HTTP resource provider.
///
/// Kept pure (no `dart:io`, no bindings, no state) so the security-relevant
/// decisions — where a redirect goes and whether the app-configured headers
/// may ride along — are unit-testable without a server; see
/// `test/http_redirect_policy_test.dart`.
library;

/// Why [nextRedirectHop] refused to follow a redirect.
class RedirectRefusedException implements Exception {
  const RedirectRefusedException(this.message);

  final String message;

  @override
  String toString() => 'RedirectRefusedException: $message';
}

/// The follow decision for one redirect response.
class RedirectHop {
  const RedirectHop({required this.target, required this.sendCustomHeaders});

  /// The absolute URL the chain continues at.
  final Uri target;

  /// Whether the app-configured headers (global `setHttpHeaders` and per-map
  /// `setCustomHeaders` alike, Authorization and API keys included) may be
  /// sent to [target]. False as soon as the target's origin differs from the
  /// ORIGINAL request's: a server must not be able to bounce a request — and
  /// the credentials on it — to a host the app never configured headers for.
  /// Headers the provider generates itself (If-None-Match, Range) are not
  /// secrets and ride every hop regardless.
  final bool sendCustomHeaders;
}

/// Decides how one response in a redirect chain is handled.
///
/// Returns null when [statusCode] is not a redirect (the response is final),
/// the [RedirectHop] to follow otherwise, or throws
/// [RedirectRefusedException] when following would be unsafe:
///
/// - a redirect status without a usable Location header (matching dart:io);
/// - a target that is not http(s), which the provider could not fetch anyway;
/// - an https-to-http downgrade. The upstream native transports follow such
///   downgrades (an oversight, not a contract), sending a URL the app chose
///   to be confidential over cleartext; deliberately not replicated here.
///
/// Method handling needs no decision: the provider only ever issues GET, so
/// the one thing the redirect codes disagree on (303 — and in practice
/// 301/302 — rewrite the method to GET, 307/308 preserve it) is a no-op.
RedirectHop? nextRedirectHop({
  required int statusCode,
  required String? location,
  required Uri requestUrl,
  required Uri originalUrl,
}) {
  const redirectStatuses = {301, 302, 303, 307, 308};
  if (!redirectStatuses.contains(statusCode)) return null;
  if (location == null || location.isEmpty) {
    throw RedirectRefusedException(
      'HTTP $statusCode from $requestUrl carries no Location header',
    );
  }
  // A relative Location resolves against the URL that answered, not the
  // original one: intermediate hops may have moved the chain elsewhere.
  final target = requestUrl.resolve(location);
  if (!target.isScheme('http') && !target.isScheme('https')) {
    throw RedirectRefusedException(
      'redirect to non-http(s) URL $target from $requestUrl',
    );
  }
  if (requestUrl.isScheme('https') && target.isScheme('http')) {
    throw RedirectRefusedException(
      'insecure redirect from $requestUrl to $target (https to http)',
    );
  }
  return RedirectHop(
    target: target,
    sendCustomHeaders: _sameOrigin(target, originalUrl),
  );
}

/// Scheme + host + port, the boundary custom headers must not cross. [Uri]
/// already lowercases scheme and host on parse, and [Uri.port] substitutes
/// the scheme default when absent, so `https://a.com` and `https://a.com:443`
/// compare equal.
bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;
