import Flutter
import Foundation
import MapLibre
import UIKit

public class MapLibreMapsPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = MapLibreMapFactory(withRegistrar: registrar)
        registrar.register(instance, withId: "plugins.flutter.io/maplibre_gl")

        // Register the header-injection protocol before any MLNMapView is created.
        // MLNNetworkConfiguration docs require sessionConfiguration to be set before
        // the first map view; we bake the protocol class into the session config here
        // so that MapLibreHeadersProtocol can intercept requests at call time.
        let sessionConfig = MLNNetworkConfiguration.sharedManager.sessionConfiguration
            ?? URLSessionConfiguration.default
        sessionConfig.protocolClasses = [MapLibreHeadersProtocol.self]
            + (sessionConfig.protocolClasses ?? [])
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig

        MapLibreGlobalHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: GlobalHostApi(registrar: registrar)
        )
    }
}
