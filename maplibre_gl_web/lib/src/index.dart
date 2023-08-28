@JS()
library mapboxgl.base;

import 'package:js/js.dart';

@JS('maplibregl')
abstract class Mapbox {
  ///  Gets and sets the map's [access token](https://www.mapbox.com/help/define-access-token/).
  ///
  ///  @var {string} accessToken
  ///  @example
  ///  mapboxgl.accessToken = myAccessToken;
  ///  @see [Display a map](https://www.mapbox.com/mapbox-gl-js/examples/)
  external static String get accessToken;
  external static set accessToken(String token);

  ///  Gets and sets the map's default API URL for requesting tiles, styles, sprites, and glyphs
  ///
  ///  @var {string} baseApiUrl
  ///  @example
  ///  mapboxgl.baseApiUrl = 'https://api.mapbox.com';
  external static String get baseApiUrl;
  external static set baseApiUrl(String url);

  ///  Gets and sets the number of web workers instantiated on a page with GL JS maps.
  ///  By default, it is set to half the number of CPU cores (capped at 6).
  ///  Make sure to set this property before creating any map instances for it to have effect.
  ///
  ///  @var {string} workerCount
  ///  @example
  ///  mapboxgl.workerCount = 2;
  external static num get workerCount;
  external static set workerCount(num count);

  ///  Gets and sets the maximum number of images (raster tiles, sprites, icons) to load in parallel,
  ///  which affects performance in raster-heavy maps. 16 by default.
  ///
  ///  @var {string} maxParallelImageRequests
  ///  @example
  ///  mapboxgl.maxParallelImageRequests = 10;
  external static num get maxParallelImageRequests;
  external static set maxParallelImageRequests(num numRequests);

  ///  Test whether the browser [supports Mapbox GL JS](https://www.mapbox.com/help/mapbox-browser-support/#mapbox-gl-js).
  ///
  ///  @function supported
  ///  @param {boolean} [failIfMajorPerformanceCaveat]=false If `true`,
  ///    the function will return `false` if the performance of Mapbox GL JS would
  ///    be dramatically worse than expected (e.g. a software WebGL renderer would be used).
  ///  @return {boolean}
  ///  @example
  ///  mapboxgl.supported() // = true
  ///  @see [Check for browser support](https://www.mapbox.com/mapbox-gl-js/example/check-for-support/)
  external static bool supported(bool failIfMajorPerformanceCaveat);

  ///  The version of Mapbox GL JS in use as specified in `package.json`,
  ///  `CHANGELOG.md`, and the GitHub release.
  ///
  ///  @var {string} version
  external static String get version;

  ///  Clears browser storage used by this library. Using this method flushes the Mapbox tile
  ///  cache that is managed by this library. Tiles may still be cached by the browser
  ///  in some cases.
  ///
  ///  This API is supported on browsers where the [`Cache` API](https://developer.mozilla.org/en-US/docs/Web/API/Cache)
  ///  is supported and enabled. This includes all major browsers when pages are served over
  ///  `https://`, except Internet Explorer and Edge Mobile.
  ///
  ///  When called in unsupported browsers or environments (private or incognito mode), the
  ///  callback will be called with an error argument.
  ///
  ///  @function clearStorage
  ///  @param {Function} callback Called with an error argument if there is an error.
  external static void clearStorage(Function(Error e) f);

  /// Sets the map's [RTL text plugin](https://www.mapbox.com/mapbox-gl-js/plugins/#mapbox-gl-rtl-text).
  /// Necessary for supporting the Arabic and Hebrew languages, which are written right-to-left. Mapbox Studio loads this plugin by default.
  ///
  /// @function setRTLTextPlugin
  /// @param {string} pluginURL URL pointing to the Mapbox RTL text plugin source.
  /// @param {Function} callback Called with an error argument if there is an error.
  /// @param {boolean} lazy If set to `true`, mapboxgl will defer loading the plugin until rtl text is encountered,
  ///    rtl text will then be rendered only after the plugin finishes loading.
  /// @example
  /// mapboxgl.setRTLTextPlugin('https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-rtl-text/v0.2.0/mapbox-gl-rtl-text.js');
  /// @see [Add support for right-to-left scripts](https://www.mapbox.com/mapbox-gl-js/example/mapbox-gl-rtl-text/)
  external static void setRTLTextPlugin(
      String pluginURL, Function callback, bool lazy);

  /// Gets the map's [RTL text plugin](https://www.mapbox.com/mapbox-gl-js/plugins/#mapbox-gl-rtl-text) status.
  /// The status can be `unavailable` (i.e. not requested or removed), `loading`, `loaded` or `error`.
  /// If the status is `loaded` and the plugin is requested again, an error will be thrown.
  external static String getRTLTextPluginStatus();
}
