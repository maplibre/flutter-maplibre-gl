import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/offline_regions_page.dart';

class OfflineRegionMapPage extends StatefulWidget {
  const OfflineRegionMapPage(this.item, {super.key});

  final OfflineRegionListItem item;

  @override
  State<OfflineRegionMapPage> createState() => _OfflineRegionMapPageState();
}

class _OfflineRegionMapPageState extends State<OfflineRegionMapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Offline Region: ${widget.item.name}')),
      body: MaplibreMap(
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: widget.item.offlineRegionDefinition.minZoom,
        ),
        minMaxZoomPreference: MinMaxZoomPreference(
          widget.item.offlineRegionDefinition.minZoom,
          widget.item.offlineRegionDefinition.maxZoom,
        ),
        styleString: widget.item.offlineRegionDefinition.mapStyleUrl,
        cameraTargetBounds: CameraTargetBounds(
          widget.item.offlineRegionDefinition.bounds,
        ),
      ),
    );
  }

  LatLng get _center {
    final bounds = widget.item.offlineRegionDefinition.bounds;
    final lat = (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final lng = (bounds.southwest.longitude + bounds.northeast.longitude) / 2;
    return LatLng(lat, lng);
  }
}
