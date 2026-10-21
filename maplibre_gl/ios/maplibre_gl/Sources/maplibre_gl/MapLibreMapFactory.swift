import Flutter

class MapLibreMapFactory: NSObject, FlutterPlatformViewFactory {
    var registrar: FlutterPluginRegistrar

    init(withRegistrar registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    /// The creation params are a `PgCreationParams`, which Dart encodes with
    /// the codec of the messages.
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return MessagesPigeonCodec.shared
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView
    {
        return MapLibreMapController(
            withFrame: frame,
            viewIdentifier: viewId,
            arguments: args,
            registrar: registrar
        )
    }
}
