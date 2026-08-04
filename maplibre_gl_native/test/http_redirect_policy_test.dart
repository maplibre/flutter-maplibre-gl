import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/engine/core/http_redirect_policy.dart';

/// The provider's redirect decisions, exercised as the pure function so no
/// server is needed. The security-relevant cases (cross-origin header
/// stripping, https-to-http refusal) are the point of the file.
void main() {
  final original = Uri.parse('https://tiles.example.com/style.json');

  RedirectHop? decide(
    int status,
    String? location, {
    Uri? requestUrl,
    Uri? originalUrl,
  }) => nextRedirectHop(
    statusCode: status,
    location: location,
    requestUrl: requestUrl ?? original,
    originalUrl: originalUrl ?? original,
  );

  group('nextRedirectHop', () {
    test('non-redirect statuses are final', () {
      for (final status in [200, 204, 206, 304, 400, 404, 429, 500]) {
        expect(decide(status, 'https://elsewhere.example.com/'), isNull);
      }
    });

    test('every redirect status is followed', () {
      for (final status in [301, 302, 303, 307, 308]) {
        final hop = decide(status, 'https://tiles.example.com/v2/style.json');
        expect(hop, isNotNull, reason: 'status $status');
        expect(hop!.target.path, '/v2/style.json');
      }
    });

    test('a relative Location resolves against the answering URL', () {
      final hop = decide(
        302,
        '../fonts/glyphs.pbf',
        requestUrl: Uri.parse('https://tiles.example.com/styles/basic.json'),
      );
      expect(
        hop!.target,
        Uri.parse('https://tiles.example.com/fonts/glyphs.pbf'),
      );
      expect(hop.sendCustomHeaders, isTrue);
    });

    test('same-origin redirects keep the custom headers', () {
      final hop = decide(301, 'https://tiles.example.com/other');
      expect(hop!.sendCustomHeaders, isTrue);
    });

    test('a host change strips the custom headers but is still followed', () {
      final hop = decide(302, 'https://cdn.example.net/style.json');
      expect(hop!.target.host, 'cdn.example.net');
      expect(hop.sendCustomHeaders, isFalse);
    });

    test('a port change is a different origin', () {
      final hop = decide(302, 'https://tiles.example.com:8443/style.json');
      expect(hop!.sendCustomHeaders, isFalse);
    });

    test(
      'the default port and an explicit default port are the same origin',
      () {
        final hop = decide(302, 'https://tiles.example.com:443/style.json');
        expect(hop!.sendCustomHeaders, isTrue);
      },
    );

    test('an http-to-https upgrade changes the origin too', () {
      final insecure = Uri.parse('http://tiles.example.com/style.json');
      final hop = decide(
        302,
        'https://tiles.example.com/style.json',
        requestUrl: insecure,
        originalUrl: insecure,
      );
      expect(hop!.sendCustomHeaders, isFalse);
    });

    test('headers come back when a chain returns to the original origin', () {
      // tiles.example.com -> cdn.example.net -> tiles.example.com: the last
      // hop targets the origin the app configured, so it gets headers again.
      final hop = decide(
        302,
        'https://tiles.example.com/final.json',
        requestUrl: Uri.parse('https://cdn.example.net/hop'),
      );
      expect(hop!.sendCustomHeaders, isTrue);
    });

    test('an https-to-http downgrade is refused outright', () {
      expect(
        () => decide(302, 'http://tiles.example.com/style.json'),
        throwsA(isA<RedirectRefusedException>()),
      );
    });

    test('a non-http(s) target is refused', () {
      expect(
        () => decide(302, 'ftp://tiles.example.com/style.json'),
        throwsA(isA<RedirectRefusedException>()),
      );
    });

    test('a redirect without a Location header is refused', () {
      expect(
        () => decide(302, null),
        throwsA(isA<RedirectRefusedException>()),
      );
      expect(
        () => decide(302, ''),
        throwsA(isA<RedirectRefusedException>()),
      );
    });
  });
}
