part of '../maplibre_gl_platform_interface.dart';

class RequestParameters {
  final String url;
  final Map<String, String>? headers;

  const RequestParameters({required this.url, this.headers});

  Map<String, dynamic> toMap() => {
        'url': url,
        if (headers != null) 'headers': headers,
      };
}
