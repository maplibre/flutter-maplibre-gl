import Flutter
import Foundation

/// The calls of one map, from Dart to native.
///
/// Each method hands its arguments to the controller method of the same name
/// through `MapLibreMapController.runCall` and adapts the controller's
/// `FlutterResult` answer to the Pigeon completion. Style data maps (layer
/// and source properties, the light) go over as `plainValue` makes them.
///
/// The generated setup holds this object strongly while its handlers are
/// registered, so the controller is held weakly: a strong reference would
/// keep the controller, and its MLNMapView, alive after the view is gone.
final class MapHostApi: MapLibreMapHostApi {
    weak var controller: MapLibreMapController?

    // MARK: Registration

    /// A map's channels: its view id as suffix, on one engine's messenger.
    private struct Channels: Hashable {
        let messenger: ObjectIdentifier
        let suffix: String
    }

    /// The API whose handlers each map's channels currently hold. Read and
    /// written on the main thread only, where the engine requires handlers
    /// to be set.
    private static var owners: [Channels: ObjectIdentifier] = [:]

    /// Sets up this API's handlers on the channels of the map with the given
    /// suffix, taking them over from any API that held them.
    func register(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String) {
        MapLibreMapHostApiSetup.setUp(
            binaryMessenger: binaryMessenger,
            api: self,
            messageChannelSuffix: messageChannelSuffix
        )
        let channels = Channels(
            messenger: ObjectIdentifier(binaryMessenger),
            suffix: messageChannelSuffix
        )
        Self.owners[channels] = ObjectIdentifier(self)
    }

    /// Removes the handlers `register` set up, unless another API took the
    /// channels over since.
    ///
    /// After a hot restart the new Dart code numbers its platform views from
    /// 0 again, so a new map can get the view id of an old one whose
    /// controller is still alive, and register first. Removing the handlers
    /// by channel name in the old controller's late `deinit` would leave the
    /// new map without them: frozen, every call failing.
    func unregister(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String) {
        let channels = Channels(
            messenger: ObjectIdentifier(binaryMessenger),
            suffix: messageChannelSuffix
        )
        guard Self.owners[channels] == ObjectIdentifier(self) else { return }
        Self.owners[channels] = nil
        MapLibreMapHostApiSetup.setUp(
            binaryMessenger: binaryMessenger,
            api: nil,
            messageChannelSuffix: messageChannelSuffix
        )
    }

    /// Whether this API still holds the channels `register` set up, the same
    /// test `unregister` makes.
    func ownsChannels(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String) -> Bool {
        let channels = Channels(
            messenger: ObjectIdentifier(binaryMessenger),
            suffix: messageChannelSuffix
        )
        return Self.owners[channels] == ObjectIdentifier(self)
    }

    // MARK: Map

    func mapWaitForMap(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapWaitForMap(result: $1) }
    }

    func mapUpdate(
        options: PgMapOptions,
        completion: @escaping (Result<PgCameraPosition?, Error>) -> Void
    ) {
        let result = pigeonResult(completion) { $0 as? PgCameraPosition }
        // The options that move the camera wait for the view to have a size,
        // as the camera calls do. The others apply at once, so they keep their
        // place among the calls made after them, such as a setGeoJsonSource.
        let (camera, others) = Convert.splitCameraOptions(options)
        guard let camera = camera else {
            run(result) { $0.mapUpdate(options: options, result: $1) }
            return
        }
        if let others = others {
            // The camera part answers the call.
            run({ _ in }) { $0.mapUpdate(options: others, result: $1) }
        }
        run(result, kind: .movesCamera) { $0.mapUpdate(options: camera, result: $1) }
    }

    func mapUpdateMyLocationTrackingMode(
        mode: PgMyLocationTrackingMode,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.mapUpdateMyLocationTrackingMode(mode: mode, result: $1) }
    }

    func mapMatchMapLanguageWithDeviceDefault(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.mapMatchMapLanguageWithDeviceDefault(result: $1) }
    }

    func mapUpdateContentInsets(
        insets: PgEdgeInsets,
        animated: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion), kind: .movesCamera) {
            $0.mapUpdateContentInsets(insets: insets, animated: animated, result: $1)
        }
    }

    func mapSetMapLanguage(
        language: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.mapSetMapLanguage(language: language, result: $1) }
    }

    func mapSetTelemetryEnabled(
        enabled: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.mapSetTelemetryEnabled(enabled: enabled, result: $1) }
    }

    func mapGetTelemetryEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? Bool }) { $0.mapGetTelemetryEnabled(result: $1) }
    }

    func mapSetMaximumFps(fps: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapSetMaximumFps(fps: fps, result: $1) }
    }

    func mapForceOnlineMode(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapForceOnlineMode(result: $1) }
    }

    func mapPause(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapPause(result: $1) }
    }

    func mapResume(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapResume(result: $1) }
    }

    func mapGetStyle(completion: @escaping (Result<String?, Error>) -> Void) {
        run(pigeonResult(completion) { $0 as? String }) { $0.mapGetStyle(result: $1) }
    }

    func mapSetCustomHeaders(
        headers: [String: String],
        filter: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.mapSetCustomHeaders(headers: headers, filter: filter, result: $1)
        }
    }

    func mapGetCustomHeaders(completion: @escaping (Result<[String: String], Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? [String: String] }) {
            $0.mapGetCustomHeaders(result: $1)
        }
    }

    func mapInvalidateAmbientCache(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapInvalidateAmbientCache(result: $1) }
    }

    func mapClearAmbientCache(completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.mapClearAmbientCache(result: $1) }
    }

    func mapTakeSnapshot(
        width: Int64?,
        height: Int64?,
        completion: @escaping (Result<FlutterStandardTypedData?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? FlutterStandardTypedData }) {
            $0.mapTakeSnapshot(width: width, height: height, result: $1)
        }
    }

    // MARK: Camera

    func cameraAnimate(
        cameraUpdate: PgCameraUpdate,
        duration: Int64?,
        completion: @escaping (Result<Bool?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? Bool }, kind: .movesCamera) {
            $0.cameraAnimate(cameraUpdate: cameraUpdate, duration: duration, result: $1)
        }
    }

    func cameraMove(
        cameraUpdate: PgCameraUpdate,
        completion: @escaping (Result<Bool?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? Bool }, kind: .movesCamera) {
            $0.cameraMove(cameraUpdate: cameraUpdate, result: $1)
        }
    }

    func cameraEase(
        cameraUpdate: PgCameraUpdate,
        duration: Int64?,
        interpolation: PgCameraAnimationInterpolation?,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? Bool }, kind: .movesCamera) {
            $0.cameraEase(
                cameraUpdate: cameraUpdate,
                duration: duration,
                interpolation: interpolation,
                result: $1
            )
        }
    }

    func mapSetCameraBounds(
        west: Double,
        north: Double,
        south: Double,
        east: Double,
        padding: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion), kind: .movesCamera) {
            $0.mapSetCameraBounds(
                west: west,
                north: north,
                south: south,
                east: east,
                padding: padding,
                result: $1
            )
        }
    }

    func mapQueryCameraPosition(completion: @escaping (Result<PgCameraPosition, Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? PgCameraPosition }, kind: .readsCamera) {
            $0.mapQueryCameraPosition(result: $1)
        }
    }

    func mapGetVisibleRegion(completion: @escaping (Result<PgLatLngBounds, Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? PgLatLngBounds }, kind: .readsCamera) {
            $0.mapGetVisibleRegion(result: $1)
        }
    }

    func mapToScreenLocation(
        latitude: Double,
        longitude: Double,
        completion: @escaping (Result<PgScreenPoint, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? PgScreenPoint }, kind: .readsCamera) {
            $0.mapToScreenLocation(latitude: latitude, longitude: longitude, result: $1)
        }
    }

    func mapToScreenLocationBatch(
        coordinates: FlutterStandardTypedData,
        completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void
    ) {
        run(
            nonNullResult(completion) { $0 as? FlutterStandardTypedData },
            kind: .readsCamera
        ) {
            $0.mapToScreenLocationBatch(coordinates: coordinates, result: $1)
        }
    }

    func mapToLatLng(
        x: Double,
        y: Double,
        completion: @escaping (Result<PgLatLng, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? PgLatLng }, kind: .readsCamera) {
            $0.mapToLatLng(x: x, y: y, result: $1)
        }
    }

    func mapGetMetersPerPixelAtLatitude(
        latitude: Double,
        completion: @escaping (Result<Double, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? Double }, kind: .readsCamera) {
            $0.mapGetMetersPerPixelAtLatitude(latitude: latitude, result: $1)
        }
    }

    // MARK: Queries

    func mapQueryRenderedFeaturesAtPoint(
        x: Double,
        y: Double,
        layerIds: [String],
        filter: String?,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? [String] }) {
            $0.mapQueryRenderedFeaturesAtPoint(
                x: x,
                y: y,
                layerIds: layerIds,
                filter: filter,
                result: $1
            )
        }
    }

    func mapQueryRenderedFeaturesInRect(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        layerIds: [String],
        filter: String?,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? [String] }) {
            $0.mapQueryRenderedFeaturesInRect(
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                layerIds: layerIds,
                filter: filter,
                result: $1
            )
        }
    }

    func mapQuerySourceFeatures(
        sourceId: String,
        sourceLayerId: String?,
        filter: String?,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? [String] }) {
            $0.mapQuerySourceFeatures(
                sourceId: sourceId,
                sourceLayerId: sourceLayerId,
                filter: filter,
                result: $1
            )
        }
    }

    // MARK: Sources

    func sourceAddGeoJson(
        sourceId: String,
        geojson: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.sourceAddGeoJson(sourceId: sourceId, geojson: geojson, result: $1)
        }
    }

    func sourceSetGeoJson(
        sourceId: String,
        geojson: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.sourceSetGeoJson(sourceId: sourceId, geojson: geojson, result: $1)
        }
    }

    func sourceSetFeature(
        sourceId: String,
        geojsonFeature: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.sourceSetFeature(sourceId: sourceId, geojsonFeature: geojsonFeature, result: $1)
        }
    }

    func sourceGetClusterExpansionZoom(
        sourceId: String,
        clusterId: Int64,
        completion: @escaping (Result<Int64, Error>) -> Void
    ) {
        // The controller answers a Swift Int.
        run(nonNullResult(completion) { value in (value as? Int).map { Int64($0) } }) {
            $0.sourceGetClusterExpansionZoom(sourceId: sourceId, clusterId: clusterId, result: $1)
        }
    }

    func sourceGetClusterChildren(
        sourceId: String,
        clusterId: Int64,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? [String] }) {
            $0.sourceGetClusterChildren(sourceId: sourceId, clusterId: clusterId, result: $1)
        }
    }

    func sourceGetClusterLeaves(
        sourceId: String,
        clusterId: Int64,
        limit: Int64,
        offset: Int64,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? [String] }) {
            $0.sourceGetClusterLeaves(
                sourceId: sourceId,
                clusterId: clusterId,
                limit: limit,
                offset: offset,
                result: $1
            )
        }
    }

    func mapEditGeoJsonSource(
        id: String,
        data: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? Bool }) {
            $0.mapEditGeoJsonSource(id: id, data: data, result: $1)
        }
    }

    func mapEditGeoJsonUrl(
        id: String,
        url: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? Bool }) {
            $0.mapEditGeoJsonUrl(id: id, url: url, result: $1)
        }
    }

    // The feature state calls have no iOS implementation: Dart rejects them
    // before sending, and they are answered not implemented otherwise.

    func sourceSetFeatureState(
        sourceId: String,
        featureId: String,
        state: [String: Any?],
        sourceLayer: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion), notImplemented)
    }

    func sourceRemoveFeatureState(
        sourceId: String,
        featureId: String?,
        stateKey: String?,
        sourceLayer: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion), notImplemented)
    }

    func sourceGetFeatureState(
        sourceId: String,
        featureId: String,
        sourceLayer: String?,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? String }, notImplemented)
    }

    // MARK: Style

    func styleAddImage(
        name: String,
        bytes: FlutterStandardTypedData,
        length: Int64,
        sdf: Bool,
        pixelRatio: Double?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleAddImage(
                name: name,
                bytes: bytes,
                sdf: sdf,
                pixelRatio: pixelRatio,
                result: $1
            )
        }
    }

    func styleAddImageSource(
        imageSourceId: String,
        bytes: FlutterStandardTypedData,
        length: Int64,
        coordinates: PgLatLngQuad,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleAddImageSource(
                imageSourceId: imageSourceId,
                bytes: bytes,
                coordinates: coordinates,
                result: $1
            )
        }
    }

    func styleUpdateImageSource(
        imageSourceId: String,
        bytes: FlutterStandardTypedData?,
        length: Int64?,
        coordinates: PgLatLngQuad?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleUpdateImageSource(
                imageSourceId: imageSourceId,
                bytes: bytes,
                coordinates: coordinates,
                result: $1
            )
        }
    }

    func styleRemoveSource(
        sourceId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.styleRemoveSource(sourceId: sourceId, result: $1) }
    }

    func styleAddLayer(
        imageLayerId: String,
        imageSourceId: String,
        minzoom: Double?,
        maxzoom: Double?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleAddLayer(
                imageLayerId: imageLayerId,
                imageSourceId: imageSourceId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                result: $1
            )
        }
    }

    func styleAddLayerBelow(
        imageLayerId: String,
        imageSourceId: String,
        belowLayerId: String,
        minzoom: Double?,
        maxzoom: Double?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleAddLayerBelow(
                imageLayerId: imageLayerId,
                imageSourceId: imageSourceId,
                belowLayerId: belowLayerId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                result: $1
            )
        }
    }

    func styleRemoveLayer(
        layerId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.styleRemoveLayer(layerId: layerId, result: $1) }
    }

    func styleMoveLayer(
        layerId: String,
        belowLayerId: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleMoveLayer(layerId: layerId, belowLayerId: belowLayerId, result: $1)
        }
    }

    func styleSetFilter(
        layerId: String,
        filter: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.styleSetFilter(layerId: layerId, filter: filter, result: $1) }
    }

    func styleGetFilter(
        layerId: String,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? String }) {
            $0.styleGetFilter(layerId: layerId, result: $1)
        }
    }

    func styleAddSource(
        sourceId: String,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.styleAddSource(sourceId: sourceId, properties: plainMap(properties), result: $1)
        }
    }

    func styleSetLight(
        light: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) { $0.styleSetLight(light: plainMap(light), result: $1) }
    }

    func styleGetLayerIds(completion: @escaping (Result<[String], Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? [String] }) { $0.styleGetLayerIds(result: $1) }
    }

    func styleGetSourceIds(completion: @escaping (Result<[String], Error>) -> Void) {
        run(nonNullResult(completion) { $0 as? [String] }) { $0.styleGetSourceIds(result: $1) }
    }

    func styleGetLayerProperties(
        layerId: String,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? String }) {
            $0.styleGetLayerProperties(layerId: layerId, result: $1)
        }
    }

    func styleGetSourceProperties(
        sourceId: String,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? String }) {
            $0.styleGetSourceProperties(sourceId: sourceId, result: $1)
        }
    }

    func styleSetStyle(style: String, completion: @escaping (Result<Void, Error>) -> Void) {
        run(voidResult(completion)) { $0.styleSetStyle(style: style, result: $1) }
    }

    // MARK: Layers

    func symbolLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.symbolLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func lineLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.lineLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func circleLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.circleLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func fillLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.fillLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func fillExtrusionLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        enableInteraction: Bool,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.fillExtrusionLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                enableInteraction: enableInteraction,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func rasterLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.rasterLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func hillshadeLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.hillshadeLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func colorReliefLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.colorReliefLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func backgroundLayerAdd(
        layerId: String,
        belowLayerId: String?,
        minzoom: Double?,
        maxzoom: Double?,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.backgroundLayerAdd(
                layerId: layerId,
                belowLayerId: belowLayerId,
                minzoom: minzoom,
                maxzoom: maxzoom,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func heatmapLayerAdd(
        sourceId: String,
        layerId: String,
        belowLayerId: String?,
        sourceLayer: String?,
        minzoom: Double?,
        maxzoom: Double?,
        filter: String?,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.heatmapLayerAdd(
                sourceId: sourceId,
                layerId: layerId,
                belowLayerId: belowLayerId,
                sourceLayer: sourceLayer,
                minzoom: minzoom,
                maxzoom: maxzoom,
                filter: filter,
                properties: plainMap(properties),
                result: $1
            )
        }
    }

    func layerSetProperties(
        layerId: String,
        properties: [String: Any?],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.layerSetProperties(layerId: layerId, properties: plainMap(properties), result: $1)
        }
    }

    func layerSetVisibility(
        layerId: String,
        visible: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.layerSetVisibility(layerId: layerId, visible: visible, result: $1)
        }
    }

    func layerSetVisibilityBatch(
        layerIds: [String],
        visible: Bool,
        completion: @escaping (Result<[String]?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? [String] }) {
            $0.layerSetVisibilityBatch(layerIds: layerIds, visible: visible, result: $1)
        }
    }

    func layerSetZoomRange(
        layerId: String,
        minzoom: Double,
        maxzoom: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.layerSetZoomRange(layerId: layerId, minzoom: minzoom, maxzoom: maxzoom, result: $1)
        }
    }

    func layerGetVisibility(
        layerId: String,
        completion: @escaping (Result<Bool?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? Bool }) {
            $0.layerGetVisibility(layerId: layerId, result: $1)
        }
    }

    func mapSetLayerFilter(
        id: String,
        filter: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? Bool }) {
            $0.mapSetLayerFilter(id: id, filter: filter, result: $1)
        }
    }

    // MARK: Location component

    func locationComponentSetTrackingCameraOptions(
        tilt: Double,
        duration: Int64?,
        completion: @escaping (Result<Bool?, Error>) -> Void
    ) {
        run(pigeonResult(completion) { $0 as? Bool }) {
            $0.locationComponentSetTrackingCameraOptions(tilt: tilt, duration: duration, result: $1)
        }
    }

    func locationComponentSetManualLocation(
        update: PgManualLocationUpdate,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        run(voidResult(completion)) {
            $0.locationComponentSetManualLocation(update: update, result: $1)
        }
    }

    func locationComponentGetLastLocation(
        completion: @escaping (Result<PgLatLng, Error>) -> Void
    ) {
        run(nonNullResult(completion) { $0 as? PgLatLng }) {
            $0.locationComponentGetLastLocation(result: $1)
        }
    }

    // MARK: Dispatch

    /// Hands a call to the controller, which runs it through `runCall`, or
    /// fails it with MAP_DISPOSED once the controller is gone.
    private func run(
        _ result: @escaping FlutterResult,
        kind: MapLibreMapController.CallKind = .plain,
        _ call: @escaping (MapLibreMapController, @escaping FlutterResult) -> Void
    ) {
        guard let controller = controller else {
            result(Self.disposedError())
            return
        }
        controller.runCall(kind, result: result) { call($0, result) }
    }

    /// The error of a call the map was disposed before it ran.
    static func disposedError() -> FlutterError {
        return FlutterError(
            code: "MAP_DISPOSED",
            message: "The map was disposed before the call reached it.",
            details: nil
        )
    }
}

// MARK: Results

/// Answers a call iOS does not implement. `pigeonResult` turns the answer
/// into the `notImplemented` error.
private func notImplemented(_: MapLibreMapController, _ result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
}

/// Like `pigeonResult`, for a return the schema declares non-null. An answer
/// `convert` cannot read fails the call with the error Pigeon's Dart side
/// raises for a null reply, rather than making a value up.
private func nonNullResult<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    convert: @escaping (Any?) -> T?
) -> FlutterResult {
    pigeonResult({ (result: Result<T?, Error>) in
        switch result {
        case let .success(value?):
            completion(.success(value))
        case .success(nil):
            completion(.failure(PigeonError(
                code: "null-error",
                message: "Host platform returned null value for non-null return value.",
                details: nil
            )))
        case let .failure(error):
            completion(.failure(error))
        }
    }, convert: convert)
}

// MARK: Nested payloads

/// A map as the standard codec decoded it. See `plainValue`.
private func plainMap(_ map: [String: Any?]) -> [String: Any] {
    map.mapValues(plainValue)
}

/// A list as the standard codec decoded it. See `plainValue`.
private func plainList(_ list: [Any?]) -> [Any] {
    list.map(plainValue)
}

/// A value as the standard codec decoded it, the shape the style data readers
/// cast from: nil as NSNull, numbers and booleans as NSNumber, maps and lists
/// at any depth as `[String: Any]` and `[Any]` without optionals. Anything
/// else, such as a string, typed data or a map with keys other than strings,
/// passes through.
private func plainValue(_ value: Any?) -> Any {
    guard let value = value else { return NSNull() }
    switch value {
    case is NSNull:
        return value
    case let map as [String: Any?]:
        return plainMap(map)
    case let list as [Any?]:
        return plainList(list)
    case let number as NSNumber:
        // A Swift Int64, Double or Bool becomes the NSNumber the codec made;
        // one that already is an NSNumber is returned unchanged.
        return number
    default:
        return value
    }
}
