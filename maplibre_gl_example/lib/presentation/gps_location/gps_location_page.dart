import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/page.dart' show ExamplePage;

class GpsLocationPage extends ExamplePage {
  const GpsLocationPage({super.key})
      : super(
          const Icon(Icons.gps_fixed),
          'GPS Location',
          needsLocationPermission: false,
        );

  @override
  Widget build(BuildContext context) {
    return const GpsLocationMap();
  }
}

class GpsLocationMap extends HookWidget {
  const GpsLocationMap({super.key});

  CameraPosition get initialLocation => const CameraPosition(
        target: LatLng(37.3, -121.8),
        zoom: 7,
      );

  @override
  Widget build(BuildContext context) {
    final mapController = useState<MapLibreMapController?>(null);
    final useDefaultLocationSettings = useState(true);
    return Scaffold(
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: (controller) {
              mapController.value = controller;
            },
            styleString: "assets/osm_style.json",
            compassEnabled: true,
            myLocationEnabled: true,
            trackCameraPosition: true,
            locationEnginePlatforms: switch (useDefaultLocationSettings.value) {
              false => const LocationEnginePlatforms(
                  androidPlatform: LocationEngineAndroidProperties(
                    interval: 1000,
                    displacement: 1,
                    priority: LocationPriority.highAccuracy,
                  ),
                ),
              true => LocationEnginePlatforms.defaultPlatform,
            },
            initialCameraPosition: initialLocation,
          ),
          Column(
            children: [
              GpsIcon(onTapAndPermissionGranted: () async {
                final currentLocation = await Location().getLocation();
                print(currentLocation);
                mapController.value?.animateCamera(
                  CameraUpdate.newLatLngZoom(
                      LatLng(
                        currentLocation.latitude!,
                        currentLocation.longitude!,
                      ),
                      9),
                );
              }),
              FloatingActionButton(
                onPressed: () {
                  useDefaultLocationSettings.value =
                      !useDefaultLocationSettings.value;
                },
                child: Text(switch (useDefaultLocationSettings.value) {
                  true => "Default",
                  false => "high",
                }),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class GpsIcon extends HookWidget {
  final Future<void> Function() onTapAndPermissionGranted;

  const GpsIcon({super.key, required this.onTapAndPermissionGranted});

  @override
  Widget build(BuildContext context) {
    final locationLoading = useState(false);
    return FloatingActionButton.small(
      onPressed: () async {
        if (locationLoading.value) {
          return;
        }
        locationLoading.value = true;
        var hasPermissions = await Location().hasPermission();
        if (hasPermissions != PermissionStatus.granted) {
          hasPermissions = await Location().requestPermission();
        }
        if (hasPermissions == PermissionStatus.granted) {
          await onTapAndPermissionGranted();
        }
        locationLoading.value = false;
      },
      child: switch (locationLoading.value) {
        true => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        false => const Icon(Icons.gps_fixed),
      },
    );
  }
}
