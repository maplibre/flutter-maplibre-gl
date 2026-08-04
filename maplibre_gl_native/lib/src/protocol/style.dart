/// Style mutation: sources, layers, filters, images, the location
/// indicator and the map language.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

/// Loads a style from a URL or an inline JSON document (auto-detected).
class SetStyleCommand extends SessionCommand {
  const SetStyleCommand(super.sessionId, this.styleString);

  final String styleString;
}

/// Adds a style source from its style-spec JSON representation.
class AddSourceJsonCommand extends SessionCommand {
  const AddSourceJsonCommand(super.sessionId, this.sourceId, this.source);

  final String sourceId;
  final Map<String, dynamic> source;
}

/// Adds a style layer from its style-spec JSON representation.
class AddLayerJsonCommand extends SessionCommand {
  const AddLayerJsonCommand(super.sessionId, this.layer, {this.beforeLayerId});

  final Map<String, dynamic> layer;
  final String? beforeLayerId;
}

/// Removes a style source by id.
class RemoveSourceCommand extends SessionCommand {
  const RemoveSourceCommand(super.sessionId, this.sourceId);

  final String sourceId;
}

/// Removes a style layer by id.
class RemoveLayerCommand extends SessionCommand {
  const RemoveLayerCommand(super.sessionId, this.layerId);

  final String layerId;
}

/// Replaces the data of an existing GeoJSON source with a decoded GeoJSON
/// document (FeatureCollection, Feature, or bare geometry).
class SetGeoJsonSourceDataCommand extends SessionCommand {
  const SetGeoJsonSourceDataCommand(super.sessionId, this.sourceId, this.data);

  final String sourceId;
  final Map<String, dynamic> data;
}

/// Points an existing GeoJSON source at a new data URL.
class SetGeoJsonSourceUrlCommand extends SessionCommand {
  const SetGeoJsonSourceUrlCommand(super.sessionId, this.sourceId, this.url);

  final String sourceId;
  final String url;
}

/// Toggles the style's symbol placement cross-fade (style default: enabled).
/// The platform disables it for the duration of a feature drag so symbol
/// position updates apply instantly instead of fading over ~300ms.
class SetPlacementTransitionsCommand extends SessionCommand {
  const SetPlacementTransitionsCommand(
    super.sessionId, {
    required this.enabled,
  });

  final bool enabled;
}

/// Updates a single feature inside a GeoJSON source. The engine merges the
/// feature into its cached copy of the source document (matched by id) and
/// re-sets the source, so only the patched feature crosses the boundary.
class SetGeoJsonFeatureCommand extends SessionCommand {
  const SetGeoJsonFeatureCommand(super.sessionId, this.sourceId, this.feature);

  final String sourceId;
  final Map<String, dynamic> feature;
}

/// Sets style-spec properties on an existing layer by name. Paint and layout
/// properties share the single name-based native accessor.
class SetLayerPropertiesCommand extends SessionCommand {
  const SetLayerPropertiesCommand(
    super.sessionId,
    this.layerId,
    this.properties,
  );

  final String layerId;
  final Map<String, dynamic> properties;
}

/// Sets (or clears, when null) the style-spec filter of a layer.
class SetFilterCommand extends SessionCommand {
  const SetFilterCommand(super.sessionId, this.layerId, this.filter);

  final String layerId;
  final Object? filter;
}

/// Registers a runtime style image (sprite) from raw premultiplied RGBA8
/// pixels, decoded on the presentation side.
class SetStyleImageCommand extends SessionCommand {
  const SetStyleImageCommand(
    super.sessionId,
    this.name,
    this.rgba, {
    required this.width,
    required this.height,
    this.pixelRatio = 1,
    this.sdf = false,
  });

  final String name;
  final Uint8List rgba;
  final int width;
  final int height;
  final double pixelRatio;
  final bool sdf;
}

/// Adds an image source from raw premultiplied RGBA8 pixels. [coordinates]
/// is [lat, lng] x 4 in top-left, top-right, bottom-right, bottom-left order.
class AddImageSourceCommand extends SessionCommand {
  const AddImageSourceCommand(
    super.sessionId,
    this.sourceId,
    this.rgba, {
    required this.width,
    required this.height,
    required this.coordinates,
  });

  final String sourceId;
  final Uint8List rgba;
  final int width;
  final int height;
  final List<double> coordinates;
}

/// Updates the pixels and/or corner coordinates of an existing image source.
class UpdateImageSourceCommand extends SessionCommand {
  const UpdateImageSourceCommand(
    super.sessionId,
    this.sourceId, {
    this.rgba,
    this.width,
    this.height,
    this.coordinates,
  });

  final String sourceId;
  final Uint8List? rgba;
  final int? width;
  final int? height;
  final List<double>? coordinates;
}

/// Renders an offscreen still image of the session's current style and
/// camera (static-mode map over an engine-owned texture) and reports the
/// result asynchronously via [SnapshotResultEvent], correlated by
/// [requestId].
///
/// [width]/[height] are the requested logical size of the still image. When
/// null the snapshot renders at the live surface size. They are honored at
/// the session's own scale factor with the camera left unchanged, so an
/// off-aspect size reveals more of the map rather than distorting it.
class TakeSnapshotCommand extends SessionCommand {
  const TakeSnapshotCommand(
    super.sessionId,
    this.requestId, {
    this.width,
    this.height,
  });

  final int requestId;
  final int? width;
  final int? height;
}

/// Adapts every style layer whose text-field references the `name` data
/// property to prefer `name:<language>` (setMapLanguage semantics).
class SetMapLanguageCommand extends SessionCommand {
  const SetMapLanguageCommand(super.sessionId, this.language);

  final String language;
}

/// Adds (or rebinds after a style reload) the location indicator layer and
/// binds its puck images, which must already be registered via
/// [SetStyleImageCommand].
class ShowLocationIndicatorCommand extends SessionCommand {
  const ShowLocationIndicatorCommand(
    super.sessionId, {
    required this.topImage,
    this.bearingImage,
  });

  final String topImage;
  final String? bearingImage;
}

/// Moves the location indicator (and optionally its bearing and accuracy
/// circle radius in meters).
class UpdateLocationIndicatorCommand extends SessionCommand {
  const UpdateLocationIndicatorCommand(
    super.sessionId, {
    required this.latitude,
    required this.longitude,
    this.bearing,
    this.accuracyRadius,
  });

  final double latitude;
  final double longitude;
  final double? bearing;
  final double? accuracyRadius;
}

/// Removes the location indicator layer.
class RemoveLocationIndicatorCommand extends SessionCommand {
  const RemoveLocationIndicatorCommand(super.sessionId);
}
